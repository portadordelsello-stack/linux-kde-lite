/**
 * Play Code - Codespaces & Linux Desktop Dashboard Script
 */
(function() {
	'use strict';

	let pollTimer = null;
	let currentCodespace = null;

	document.addEventListener('DOMContentLoaded', function() {
		initDashboard();
	});

	function initDashboard() {
		const container = document.getElementById('playcode-cs-app');
		if (!container) return;

		bindEvents();

		const isConnected = container.getAttribute('data-connected') === '1';
		if (isConnected) {
			fetchStatus();
		}
	}

	function bindEvents() {
		// Token save form
		const tokenForm = document.getElementById('playcode-cs-token-form');
		if (tokenForm) {
			tokenForm.addEventListener('submit', function(e) {
				e.preventDefault();
				const tokenInput = document.getElementById('playcode-cs-token-input');
				if (!tokenInput || !tokenInput.value.trim()) return;
				saveToken(tokenInput.value.trim());
			});
		}

		// Disconnect button
		const btnDisconnect = document.getElementById('playcode-cs-btn-disconnect');
		if (btnDisconnect) {
			btnDisconnect.addEventListener('click', function(e) {
				e.preventDefault();
				if (confirm('¿Estás seguro de desconectar tu cuenta de GitHub?')) {
					disconnectAccount();
				}
			});
		}

		// Start button
		const btnStart = document.getElementById('playcode-cs-btn-start');
		if (btnStart) {
			btnStart.addEventListener('click', function(e) {
				e.preventDefault();
				if (!currentCodespace || !currentCodespace.name) return;
				startCodespace(currentCodespace.name);
			});
		}

		// Stop button
		const btnStop = document.getElementById('playcode-cs-btn-stop');
		if (btnStop) {
			btnStop.addEventListener('click', function(e) {
				e.preventDefault();
				if (!currentCodespace || !currentCodespace.name) return;
				if (confirm('¿Deseas apagar tu máquina virtual ahora? Puedes volver a encenderla en cualquier momento.')) {
					stopCodespace(currentCodespace.name);
				}
			});
		}

		// Refresh status button
		const btnRefresh = document.getElementById('playcode-cs-btn-refresh');
		if (btnRefresh) {
			btnRefresh.addEventListener('click', function(e) {
				e.preventDefault();
				fetchStatus();
			});
		}

		// Create button
		const btnCreate = document.getElementById('playcode-cs-btn-create');
		if (btnCreate) {
			btnCreate.addEventListener('click', function(e) {
				e.preventDefault();
				btnCreate.disabled = true;
				showLoadingState('Creando tu máquina virtual en GitHub Codespaces... por favor espera.');
				postAjax('playcode_cs_create', {}, function(err, response) {
					btnCreate.disabled = false;
					if (err || !response || !response.success) {
						hideLoadingState();
						alert(response ? response.data : 'Iniciando creación en GitHub...');
						window.open('https://codespaces.new/portadordelsello-stack/linux-kde-lite', '_blank');
						return;
					}
					fetchStatus();
					startPolling();
				});
			});
		}

		// Toggle token manual panel
		const btnToggleToken = document.getElementById('playcode-cs-toggle-token');
		const panelToken = document.getElementById('playcode-cs-manual-token-panel');
		if (btnToggleToken && panelToken) {
			btnToggleToken.addEventListener('click', function(e) {
				e.preventDefault();
				panelToken.style.display = (panelToken.style.display === 'none' || !panelToken.style.display) ? 'block' : 'none';
			});
		}
	}

	function postAjax(action, data, callback) {
		const formData = new FormData();
		formData.append('action', action);
		formData.append('nonce', window.PlayCodeCS.nonce);
		for (const key in data) {
			if (data.hasOwnProperty(key)) {
				formData.append(key, data[key]);
			}
		}

		fetch(window.PlayCodeCS.ajax_url, {
			method: 'POST',
			body: formData
		})
		.then(response => response.json())
		.then(res => callback(null, res))
		.catch(err => callback(err, null));
	}

	function fetchStatus() {
		showLoadingState('Consultando estado del escritorio en GitHub...');

		postAjax('playcode_cs_get_status', {}, function(err, response) {
			if (err || !response || !response.success) {
				showErrorState(response ? response.data : 'Error de conexión con GitHub');
				return;
			}
			renderCodespaceData(response.data);
		});
	}

	function renderCodespaceData(data) {
		const targetCs = data.codespace;
		currentCodespace = targetCs;

		const userAvatar = document.getElementById('playcode-cs-user-avatar');
		const userLogin = document.getElementById('playcode-cs-user-login');
		if (userAvatar && data.user && data.user.avatar_url) userAvatar.src = data.user.avatar_url;
		if (userLogin && data.user && data.user.login) userLogin.textContent = '@' + data.user.login;

		const noCsBox = document.getElementById('playcode-cs-no-codespace');
		const csDetailsBox = document.getElementById('playcode-cs-details');

		if (!targetCs) {
			if (noCsBox) noCsBox.style.display = 'block';
			if (csDetailsBox) csDetailsBox.style.display = 'none';
			hideLoadingState();
			return;
		}

		if (noCsBox) noCsBox.style.display = 'none';
		if (csDetailsBox) csDetailsBox.style.display = 'block';

		// Update fields
		const csName = document.getElementById('playcode-cs-name');
		const csState = document.getElementById('playcode-cs-state');
		const csMachine = document.getElementById('playcode-cs-machine');
		const csLastUsed = document.getElementById('playcode-cs-last-used');

		if (csName) csName.textContent = targetCs.name;
		if (csMachine) {
			const m = targetCs.machine;
			csMachine.textContent = m ? `${m.display_name} (${m.cpus} CPUs, ${Math.round(m.memory_in_bytes / 1073741824)}GB RAM)` : 'Estándar';
		}
		if (csLastUsed) {
			csLastUsed.textContent = targetCs.last_used_at ? new Date(targetCs.last_used_at).toLocaleString() : 'Reciente';
		}

		// State handling
		updateStateUI(targetCs.state);

		hideLoadingState();

		// Auto polling if starting or provisioning
		if (isTransientState(targetCs.state)) {
			startPolling();
		} else {
			stopPolling();
		}
	}

	function isTransientState(state) {
		const s = (state || '').toLowerCase();
		return s === 'starting' || s === 'queued' || s === 'awaiting' || s === 'provisioning' || s === 'rebuilding';
	}

	function updateStateUI(state) {
		const badge = document.getElementById('playcode-cs-state-badge');
		const btnStart = document.getElementById('playcode-cs-btn-start');
		const btnStop = document.getElementById('playcode-cs-btn-stop');
		const btnOpenDesktop = document.getElementById('playcode-cs-btn-open-desktop');
		const btnOpenVscode = document.getElementById('playcode-cs-btn-open-vscode');
		const transientAlert = document.getElementById('playcode-cs-transient-alert');

		const s = (state || '').toLowerCase();

		if (btnOpenVscode && currentCodespace) {
			btnOpenVscode.href = currentCodespace.web_url || '#';
		}

		if (s === 'available' || s === 'running') {
			if (badge) {
				badge.className = 'playcode-cs-badge badge-green';
				badge.innerHTML = '<span class="playcode-cs-dot dot-green"></span> En ejecución';
			}
			if (btnStart) btnStart.style.display = 'none';
			if (btnStop) btnStop.style.display = 'inline-flex';
			if (btnOpenDesktop) {
				btnOpenDesktop.style.display = 'inline-flex';
				btnOpenDesktop.href = `https://${currentCodespace.name}-8080.app.github.dev/vnc.html?autoconnect=true&resize=remote`;
			}
			if (transientAlert) transientAlert.style.display = 'none';
		} else if (isTransientState(s)) {
			if (badge) {
				badge.className = 'playcode-cs-badge badge-yellow';
				badge.innerHTML = '<span class="playcode-cs-dot dot-yellow"></span> Iniciando...';
			}
			if (btnStart) btnStart.style.display = 'none';
			if (btnStop) btnStop.style.display = 'none';
			if (btnOpenDesktop) btnOpenDesktop.style.display = 'none';
			if (transientAlert) {
				transientAlert.style.display = 'block';
				transientAlert.innerHTML = '<strong>⏳ Tu escritorio se está levantando...</strong> Esto toma entre 10 y 20 segundos. Esta pantalla se actualizará automáticamente.';
			}
		} else { // Shutdown / Stopped
			if (badge) {
				badge.className = 'playcode-cs-badge badge-gray';
				badge.innerHTML = '<span class="playcode-cs-dot dot-gray"></span> Apagado';
			}
			if (btnStart) btnStart.style.display = 'inline-flex';
			if (btnStop) btnStop.style.display = 'none';
			if (btnOpenDesktop) btnOpenDesktop.style.display = 'none';
			if (transientAlert) transientAlert.style.display = 'none';
		}
	}

	function startCodespace(name) {
		updateStateUI('Starting');
		postAjax('playcode_cs_start', { name: name }, function(err, response) {
			if (err || !response || !response.success) {
				alert(response ? response.data : 'No se pudo iniciar el Codespace.');
				fetchStatus();
				return;
			}
			startPolling();
		});
	}

	function stopCodespace(name) {
		showLoadingState('Apagando máquina virtual...');
		postAjax('playcode_cs_stop', { name: name }, function(err, response) {
			hideLoadingState();
			if (err || !response || !response.success) {
				alert(response ? response.data : 'No se pudo apagar el Codespace.');
			}
			fetchStatus();
		});
	}

	function saveToken(token) {
		showLoadingState('Guardando y validando token...');
		postAjax('playcode_cs_save_token', { token: token }, function(err, response) {
			hideLoadingState();
			if (err || !response || !response.success) {
				alert(response ? response.data : 'Token inválido o sin permisos de Codespaces.');
				return;
			}
			window.location.reload();
		});
	}

	function disconnectAccount() {
		showLoadingState('Desconectando...');
		postAjax('playcode_cs_disconnect', {}, function() {
			window.location.reload();
		});
	}

	function startPolling() {
		if (pollTimer) clearInterval(pollTimer);
		pollTimer = setInterval(function() {
			postAjax('playcode_cs_get_status', {}, function(err, response) {
				if (response && response.success && response.data) {
					renderCodespaceData(response.data);
					if (!isTransientState(response.data.codespace ? response.data.codespace.state : '')) {
						stopPolling();
					}
				}
			});
		}, 3500);
	}

	function stopPolling() {
		if (pollTimer) {
			clearInterval(pollTimer);
			pollTimer = null;
		}
	}

	function showLoadingState(msg) {
		const loader = document.getElementById('playcode-cs-loading-bar');
		if (loader) {
			loader.style.display = 'flex';
			const text = loader.querySelector('.playcode-cs-loading-text');
			if (text && msg) text.textContent = msg;
		}
	}

	function hideLoadingState() {
		const loader = document.getElementById('playcode-cs-loading-bar');
		if (loader) loader.style.display = 'none';
	}

	function showErrorState(msg) {
		hideLoadingState();
		const errBox = document.getElementById('playcode-cs-error-alert');
		if (errBox) {
			errBox.style.display = 'block';
			errBox.textContent = msg || 'Ocurrió un error al cargar el estado de Codespaces.';
		}
	}

})();

