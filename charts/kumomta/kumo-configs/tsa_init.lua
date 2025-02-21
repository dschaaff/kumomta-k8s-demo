local tsa = require("tsa")
local kumo = require("kumo")

kumo.on("tsa_init", function()
	tsa.start_http_listener({
		listen = "0.0.0.0:8008",
		trusted_hosts = kumo.string.split(os.getenv("KUMOMTA_TSA_TRUSTED_HOSTS") or "127.0.0.1", ","),
	})
	kumo.set_diagnostic_log_filter("tsa_daemon=debug")
end)

local cached_load_shaping_data = kumo.memoize(kumo.shaping.load, {
	name = "tsa_load_shaping_data",
	ttl = "5 minutes",
	capacity = 4,
})

kumo.on("tsa_load_shaping_data", function()
	local shaping = cached_load_shaping_data({
		-- This is the default file used by the shaping helper
		-- in KumoMTA, which references the community shaping rules
		"/opt/kumomta/share/policy-extras/shaping.toml",

		-- this is our own custom shaping
		"/opt/kumomta/etc/policy/shaping.toml",
	})
	return shaping
end)
