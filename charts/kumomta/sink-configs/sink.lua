--[[
########################################################
This config runs a sink that accepts mail over smtp
and then drops it. It can be used to test sending mail
through kumo without delivering to real mailboxes
########################################################
]]
local kumo = require("kumo")
kumo.on("init", function()
	kumo.configure_accounting_db_path(os.tmpname())
	kumo.start_esmtp_listener({
		listen = "0.0.0.0:25",
		relay_hosts = { "0.0.0.0/0" },
		deferred_spool = true,
	})

	kumo.start_http_listener({
		listen = "0.0.0.0:8000",
	})

	kumo.define_spool({
		name = "data",
		path = "/var/spool/kumomta/data",
	})

	kumo.define_spool({
		name = "meta",
		path = "/var/spool/kumomta/meta",
	})

	kumo.configure_local_logs({
		log_dir = "/var/log/kumomta",
		-- Flush logs every 10 seconds.
		-- You may wish to set a larger value in your production
		-- configuration; this lower value makes it quicker to see
		-- logs while you are first getting set up.
		max_segment_duration = "10s",
	})
end)
--[[ End of INIT Section ]]
kumo.on("smtp_server_message_received", function(msg)
	-- Accept and discard all messages
	msg:set_meta("queue", "null")
end)

kumo.on("http_message_generated", function(msg)
	-- Accept and discard all messages
	msg:set_meta("queue", "null")
end)
