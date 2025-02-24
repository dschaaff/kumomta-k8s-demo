-- example config:
-- https://docs.kumomta.com/userguide/configuration/example/
--

local kumo = require("kumo")
local utils = require("policy-extras.policy_utils")

-- Unused policy helpers
-- local listener_domains = require 'policy-extras.listener_domains'
-- local log_hooks = require 'policy-extras.log_hooks'

-- START SETUP
--
-- Configure the sending IP addresses that will be used by KumoMTA to
-- connect to remote systems using the sources.lua policy helper.
-- NOTE that defining sources and pools does nothing without some form of
-- policy in effect to assign messages to the source pools you have defined.
-- SEE https://docs.kumomta.com/userguide/configuration/sendingips/
local sources = require("policy-extras.sources")
sources:setup({ "/opt/kumomta/etc/policy/sources.toml" })

-- Configure DKIM signing. In this case we use the dkim_sign.lua policy helper.
-- WARNING: THIS WILL NOT LOAD WITHOUT the dkim_data.toml FILE IN PLACE
-- See https://docs.kumomta.com/userguide/configuration/dkim/
-- TODO
local dkim_sign = require("policy-extras.dkim_sign")
local dkim_signer = dkim_sign:setup({ "/opt/kumomta/etc/policy/dkim_data.toml" })

-- Load Traffic Shaping Automation Helper
local shaping = require("policy-extras.shaping")
local shaper = shaping:setup_with_automation({
	-- see https://github.com/KumoCorp/kumomta/commit/3b61f1b92c5a416e81945432fefa2232617648f8 for pre filter details
	pre_filter = true,
	publish = kumo.string.split(os.getenv("KUMOMTA_TSA_PUBLISH_HOST") or "http://kumomta-tsa:8008", ","),
	subscribe = kumo.string.split(os.getenv("KUMOMTA_TSA_SUBSCRIBE_HOST") or "http://kumomta-tsa:8008", ","),
	extra_files = { "/opt/kumomta/etc/policy/shaping.toml" },
})

-- Configure queue management settings. These are not throttles, but instead
-- control how messages flow through the queues.
-- WARNING: ENSURE THAT WEBHOOKS AND SHAPING ARE SETUP BEFORE THE QUEUE HELPER FOR PROPER OPERATION
-- WARNING: THIS WILL NOT LOAD WITHOUT the queues.toml FILE IN PLACE
-- See https://docs.kumomta.com/userguide/configuration/queuemanagement/
local queue_module = require("policy-extras.queue")
local queue_helper = queue_module:setup({ "/opt/kumomta/etc/policy/queues.toml" })

-- END SETUP

-- START EVENT HANDLERS
--
-- Called On Startup, handles initial configuration
kumo.on("init", function()
	-- Define the default "data" spool location; this is where
	-- message bodies will be stored.
	-- See https://docs.kumomta.com/userguide/configuration/spool/
	kumo.define_spool({
		name = "data",
		path = "/var/spool/kumomta/data",
		kind = "RocksDB",
	})

	-- Define the default "meta" spool location; this is where
	-- message envelope and metadata will be stored.
	kumo.define_spool({
		name = "meta",
		path = "/var/spool/kumomta/meta",
		kind = "RocksDB",
	})
	kumo.set_spoolin_threads(os.getenv("KUMOMTA_SPOOLIN_THREADS") or 8)
	kumo.set_httpinject_threads(os.getenv("KUMOMTA_HTTPIN_THREADS") or 8)

	-- Use shared throttles and connection limits rather than in-process throttles
	-- TODO: consider implementing auth on redis
	if os.getenv("KUMOMTA_REDIS_CLUSTER_MODE") == "true" then
		REDIS_CLUSTER_MODE = true
	end
	kumo.configure_redis_throttles({
		node = os.getenv("KUMOMTA_REDIS_HOST") or "redis://kumomta-redis",
		cluster = REDIS_CLUSTER_MODE,
		pool_size = os.getenv("KUMOMTA_REDIS_POOL_SIZE") or 100,
		read_from_replicas = os.getenv("KUMOMTA_REDIS_READ_FROM_REPLICAS") or true,
		username = os.getenv("KUMOMTA_REDIS_USERNAME") or nil,
		password = os.getenv("KUMOMTA_REDIS_PASSWORD") or nil,
	})
	-- Configure logging to local disk. Separating spool and logs to separate
	-- disks helps reduce IO load and can help performance.
	-- See https://docs.kumomta.com/userguide/configuration/logging/
	-- TODO: we should be logging to stdout??
	kumo.configure_local_logs({
		log_dir = "/var/log/kumomta",
		max_segment_duration = "1 minute",
	})
	-- configure smtp listener
	kumo.start_esmtp_listener({
		listen = "0.0.0.0:2500",
		relay_hosts = { "0.0.0.0/0" },
	})

	-- Configure HTTP Listeners for injection and management APIs.
	-- See https://docs.kumomta.com/userguide/configuration/httplisteners/
	kumo.start_http_listener({
		listen = "0.0.0.0:8000",
		trusted_hosts = kumo.string.split(os.getenv("KUMOMTA_TRUSTED_HOSTS") or "0.0.0.0", ","),
		-- trusted_hosts = trusted_hosts_table,
	})

	-- kumo.start_esmtp_listener({
	-- 	listen = "0.0.0.0:25",
	-- 	trusted_hosts = kumo.string.split(os.getenv("KUMOMTA_TRUSTED_HOSTS") or "0.0.0.0", ","),
	-- })

	-- Configure bounce classification.
	-- See https://docs.kumomta.com/userguide/configuration/bounce/
	kumo.configure_bounce_classifier({
		files = {
			"/opt/kumomta/share/bounce_classifier/iana.toml",
		},
	})
	shaper.setup_publish()
end)

-- Call the Traffic Shaping Automation Helper to configure shaping rules.
kumo.on("get_egress_path_config", shaper.get_egress_path_config)
-- Processing of incoming messages via HTTP
kumo.on("http_message_generated", function(msg)
	-- TM:1 Aug 2024 - added this to ensure Massage ID is added:
	local failed = msg:check_fix_conformance(
		-- check for and reject messages with these issues:
		"MISSING_COLON_VALUE",
		-- fix messages with these issues:
		"LINE_TOO_LONG|NAME_ENDS_WITH_SPACE|NEEDS_TRANSFER_ENCODING|NON_CANONICAL_LINE_ENDINGS|MISSING_DATE_HEADER|MISSING_MESSAGE_ID_HEADER|MISSING_MIME_VERSION"
	)
	if failed then
		kumo.reject(552, string.format("5.6.0 %s", failed))
	end

	queue_helper:apply(msg)
	if os.getenv("KUMOMTA_SINK_ENABLED") == "true" then
		msg:set_meta("routing_domain", os.getenv("KUMOMTA_SINK_ENDPOINT") or "kumomta-sink.default.svc.cluster.local")
	end
	-- SIGNING MUST COME LAST OR YOU COULD BREAK YOUR DKIM SIGNATURES
	dkim_signer(msg)
end)

-- Use this to lookup and confirm a user/password credential for http api
kumo.on("http_server_validate_auth_basic", function(user, password)
	return cached_get_auth(user, password)
end)
-- END EVENT HANDLERS

-- START UTILITY FUNCTIONS
--
-- NOTE: k8s secret should be mounted to "/opt/kumomta/etc/http_listener_keys/"
-- Secret keys should be user names, values should be password.
-- Example:
-- data:
--   userName: <some secret generated using `openssl rand -hex 16`>
function get_auth(user, password)
	local file = "/opt/kumomta/etc/http_listener_keys/" .. user
	if not cached_auth_file_exists(file) then
		return false
	end
	for line in io.lines(file) do
		if password == line then
			return true
		end
	end
	return false
end

cached_get_auth = kumo.memoize(get_auth, {
	name = "get_auth",
	ttl = "5 minutes",
	capacity = 2,
})

function auth_file_exists(file)
	local f = io.open(file, "r")
	if f then
		f:close()
	end
	return f ~= nil
end

cached_auth_file_exists = kumo.memoize(auth_file_exists, {
	name = "auth_file_exists",
	ttl = "1 minute",
	capacity = 2,
})

-- END UTILITY FUNCTIONS
