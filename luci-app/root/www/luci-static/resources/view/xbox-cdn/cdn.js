'use strict';'require ui';'require view';'require dom';'require poll';'require uci';'require fs';'require form';

return view.extend({
	load: function() {
		return Promise.all([
			uci.load('xbox-cdn'),
			L.resolveDefault(fs.read('/tmp/xbox-cdn-status.json'), null),
			L.resolveDefault(fs.exec('/usr/bin/xbox-cdn-run', ['current-config']), null)
		]);
	},

	handleRunNow: function() {
		var btn = document.getElementById('btn-run-now');
		if (!btn || btn.disabled) return;
		btn.disabled = true;
		btn.textContent = _('Running...');

		var self = this;
		fs.exec('/usr/bin/xbox-cdn-run', ['start']).then(function() {
			self.startPolling();
		}).catch(function(err) {
			ui.addNotification(null, E('p', _('Failed to start: ') + err.message));
			btn.disabled = false;
			btn.textContent = _('Run Speed Test Now');
		});
	},

	startPolling: function() {
		var self = this;
		if (this._pollTimer) return;
		this._pollTimer = window.setInterval(function() {
			L.resolveDefault(fs.exec('/usr/bin/xbox-cdn-run', ['status']), null).then(function(res) {
				var status = {};
				try {
					var p = JSON.parse(res.stdout.trim());
					if (p && typeof p === 'object') status = p;
				} catch(e) {}

				self.updateLog();

				if (status.state !== 'running') {
					window.clearInterval(self._pollTimer);
					self._pollTimer = null;
					var btn = document.getElementById('btn-run-now');
					if (btn) {
						btn.disabled = false;
						btn.textContent = _('Run Speed Test Now');
					}
					ui.addNotification(null, E('p', _('Speed test completed.')), 'info');
				}
			});
		}, 2000);
	},

	updateLog: function() {
		var logBox = document.getElementById('xbox-cdn-log');
		if (!logBox) return;
		L.resolveDefault(fs.read('/tmp/xbox-speedtest.log'), '').then(function(content) {
			logBox.value = content || _('No log output yet.');
			logBox.scrollTop = logBox.scrollHeight;
		});
	},

	handleSaveApply: function(ev, mode) {
		var maps = Array.from(
			document.getElementById('maincontent').querySelectorAll('.cbi-map')
		);
		return Promise.all(maps.map(function(map) {
			return L.dom.callClassMethod(map, 'save');
		})).then(function() {
			var cronEnabled = uci.get('xbox-cdn', 'settings', 'cron_enabled') === '1';
			var cronHour    = uci.get('xbox-cdn', 'settings', 'cron_hour')    || '3';
			var cronMin     = uci.get('xbox-cdn', 'settings', 'cron_min')     || '0';
			if (cronEnabled) {
				return fs.exec('/usr/bin/xbox-cdn-cron', ['enable', cronHour, cronMin]);
			} else {
				return fs.exec('/usr/bin/xbox-cdn-cron', ['disable']);
			}
		}).then(function() {
			ui.changes.apply(mode === '0');
		}).catch(function(err) {
			ui.addNotification(null, E('p', _('Save failed: ') + err.message));
		});
	},

	render: function(data) {
		var statusRaw = data[1];
		var currentConfig = data[2] ? (data[2].stdout || '') : '';
		var status = {};
		try {
			var parsed = JSON.parse(statusRaw);
			if (parsed && typeof parsed === 'object') status = parsed;
		} catch(e) {}

		var self = this;
		var m, s, o;

		m = new form.Map('xbox-cdn', _('Xbox CDN Speed Optimization'),
			_('Test multiple CDN nodes and apply the fastest IP to your DNS resolver.'));

		// ===== Status Section =====
		s = m.section(form.NamedSection, 'settings', 'settings', _('Status'));
		s.anonymous = true;

		o = s.option(form.DummyValue, '_status', _('Current State'));
		o.rawhtml = true;
		o.cfgvalue = function() {
			var stateStr = status.state === 'done'    ? _('Last run completed') :
			               status.state === 'running' ? '<span style="color:green;font-weight:bold">' + _('Running...') + '</span>' :
			               _('Never run');
			var currentMode = uci.get('xbox-cdn', 'settings', 'mode') || 'dnsmasq';
			return '<div id="xbox-cdn-status-info">' +
				'<strong>' + _('Status') + ':</strong> ' + stateStr + '<br>' +
				'<strong>' + _('Last run') + ':</strong> ' + (status.last_run || '—') + '<br>' +
				'<strong>' + _('Mode') + ':</strong> ' + currentMode +
				'</div>';
		};

		o = s.option(form.DummyValue, '_run', _('Manual Trigger'));
		o.rawhtml = true;
		o.cfgvalue = function() {
			return '<button id="btn-run-now" class="cbi-button cbi-button-apply" type="button">' +
				_('Run Speed Test Now') + '</button>';
		};
		o.write = function() {};

		// ===== Settings Section =====
		s = m.section(form.NamedSection, 'settings', 'settings', _('Settings'));
		s.anonymous = true;

		o = s.option(form.ListValue, 'mode', _('Output Target'),
			_('Which DNS resolver receives the optimized IP rules.'));
		o.value('smartdns', 'SmartDNS  (address /domain/ip)');
		o.value('dnsmasq',  'dnsmasq   (address=/domain/ip)');
		o.default = 'dnsmasq';

		o = s.option(form.Flag, 'cron_enabled', _('Scheduled Speed Test'),
			_('Run automatically at a fixed time every day.'));
		o.default = '0';

		o = s.option(form.Value, 'cron_hour', _('Hour (0–23)'));
		o.datatype = 'range(0,23)';
		o.placeholder = '3';
		o.default = '3';
		o.depends('cron_enabled', '1');

		o = s.option(form.Value, 'cron_min', _('Minute (0–59)'));
		o.datatype = 'range(0,59)';
		o.placeholder = '0';
		o.default = '0';
		o.depends('cron_enabled', '1');

		// ===== Log Section =====
		s = m.section(form.NamedSection, 'settings', 'settings', _('Last Run Log'));
		s.anonymous = true;

		o = s.option(form.DummyValue, '_log', _('Output'));
		o.rawhtml = true;
		o.cfgvalue = function() {
			return '<div style="grid-column:1/-1;margin:0 -1.5em">' +
				'<textarea id="xbox-cdn-log" readonly wrap="off" ' +
				'style="width:100%;height:400px;font-family:monospace;font-size:12px;' +
				'background:#111;color:#ddd;padding:10px;box-sizing:border-box;display:block;' +
				'overflow-x:auto;white-space:pre;word-wrap:normal;overflow-wrap:normal">' +
				_('No log output yet. Run a test first.') + '</textarea></div>';
		};
		o.write = function() {};

		return m.render().then(function(node) {
			requestAnimationFrame(function() {
				var btn = document.getElementById('btn-run-now');
				if (btn) {
					btn.addEventListener('click', function() {
						self.handleRunNow();
					});
				}
			});

			self.updateLog();

			if (status.state === 'running') self.startPolling();

			return node;
		});
	}
});
