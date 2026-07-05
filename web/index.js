// OptiFreight Frontend Controller

// Global App State
let appState = {
    hubs: [],
    rawArcs: [],
    shipments: [],
    activeDatasetName: "None",
    activeTaskId: null,
    pollInterval: null,
    map: null,
    layers: {
        hubs: null,
        networkArcs: null,
        shipmentQueries: null,
        optimizedRoutes: null
    },
    defaultParameters: null,
    lastResult: null,
    editingShipmentIdx: null,
    visibleModes: { road: true, rail: true, air: true, ship: true }
};

// Mode Aesthetics
const modeColors = {
    "road": "#10b981", // green
    "rail": "#3b82f6", // blue
    "air": "#ef4444",  // red
    "ship": "#8b5cf6"  // purple
};

// Initialize Leaflet Map
function initMap() {
    // Center of Europe
    appState.map = L.map('map', {
        preferCanvas: true
    }).setView([50.1109, 8.6821], 5);

    // Sleek dark-mode tile layer
    L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>',
        subdomains: 'abcd',
        maxZoom: 20
    }).addTo(appState.map);

    // Initialize layers
    appState.layers.hubs = L.featureGroup().addTo(appState.map);
    appState.layers.networkArcs = L.featureGroup().addTo(appState.map);
    appState.layers.shipmentQueries = L.featureGroup().addTo(appState.map);
    appState.layers.optimizedRoutes = L.featureGroup().addTo(appState.map);
}

// Update Map Renderings
function drawHubsOnMap() {
    appState.layers.hubs.clearLayers();
    
    appState.hubs.forEach(hub => {
        if (hub.latitude !== null && hub.longitude !== null) {
            const marker = L.circleMarker([hub.latitude, hub.longitude], {
                radius: 6,
                fillColor: '#1e293b',
                color: '#3b82f6',
                weight: 2,
                opacity: 0.9,
                fillOpacity: 0.9
            });
            
            const tooltipContent = `
                <div class="map-tooltip">
                    <strong>${hub.name}</strong><br>
                    <span style="color: #64748b; font-size: 0.75rem;">ID: ${hub.id}</span><br>
                    <span style="font-size: 0.75rem; font-weight: 600;">Modes: ${hub.supported_modes.join(', ')}</span>
                </div>
            `;
            marker.bindTooltip(tooltipContent, { className: 'custom-leaflet-tooltip' });
            marker.addTo(appState.layers.hubs);
        }
    });
}

function drawNetworkArcsOnMap() {
    appState.layers.networkArcs.clearLayers();
    
    // Draw raw connections with light mode color
    const plotted = new Set();
    appState.rawArcs.forEach(arc => {
        if (appState.visibleModes[arc.mode] === false) return;
        const fromHub = appState.hubs.find(h => h.id === arc.from);
        const toHub = appState.hubs.find(h => h.id === arc.to);
        
        if (fromHub && toHub && fromHub.latitude !== null && toHub.latitude !== null) {
            const key = [fromHub.id, toHub.id, arc.mode].sort().join('-');
            if (plotted.has(key)) return;
            plotted.add(key);
            
            const color = modeColors[arc.mode] || '#64748b';
            const polyline = L.polyline([
                [fromHub.latitude, fromHub.longitude],
                [toHub.latitude, toHub.longitude]
            ], {
                color: color,
                weight: 1.5,
                opacity: 0.25,
                dashArray: arc.arc_type === 'transfer' ? '4,4' : null
            });
            
            polyline.bindTooltip(`${arc.mode.toUpperCase()}: ${fromHub.id} ↔ ${toHub.id} (${arc.dist.toFixed(1)} km)`, { sticky: true });
            polyline.addTo(appState.layers.networkArcs);
        }
    });
}

function drawActiveShipmentsOnMap() {
    appState.layers.shipmentQueries.clearLayers();
    
    appState.shipments.forEach(ship => {
        if (ship._showOnMap) {
            const fromHub = appState.hubs.find(h => h.id === ship.start_hub);
            const toHub = appState.hubs.find(h => h.id === ship.end_hub);
            
            if (fromHub && toHub && fromHub.latitude !== null && toHub.latitude !== null) {
                const polyline = L.polyline([
                    [fromHub.latitude, fromHub.longitude],
                    [toHub.latitude, toHub.longitude]
                ], {
                    color: '#f59e0b', // orange
                    weight: 2,
                    opacity: 0.75,
                    dashArray: '5,10'
                });
                
                polyline.bindTooltip(`Shipment Query: ${ship.id} (${fromHub.id} ➔ ${toHub.id})`, { sticky: true });
                polyline.addTo(appState.layers.shipmentQueries);
            }
        }
    });
}

function drawOptimizedRoutesOnMap(selectedShipmentId = null) {
    appState.layers.optimizedRoutes.clearLayers();
    if (!appState.lastResult || !appState.lastResult.shipment_routes) return;
    
    Object.entries(appState.lastResult.shipment_routes).forEach(([sId, route]) => {
        // Filter by shipment ID if requested
        if (selectedShipmentId !== null && sId !== selectedShipmentId) return;
        
        route.forEach(arc => {
            if (arc.arc_type === 'transport') {
                if (appState.visibleModes[arc.mode] === false) return;
                const fromHub = appState.hubs.find(h => h.id === arc.from_hub);
                const toHub = appState.hubs.find(h => h.id === arc.to_hub);
                
                if (fromHub && toHub && fromHub.latitude !== null && toHub.latitude !== null) {
                    const color = modeColors[arc.mode] || '#f59e0b';
                    const polyline = L.polyline([
                        [fromHub.latitude, fromHub.longitude],
                        [toHub.latitude, toHub.longitude]
                    ], {
                        color: color,
                        weight: selectedShipmentId !== null ? 6 : 4,
                        opacity: selectedShipmentId !== null ? 0.95 : 0.65
                    });
                    
                    const popupContent = `
                        <div class="map-popup">
                            <h4 style="color: ${color}; font-weight: 700; margin-bottom: 4px;">${arc.mode.toUpperCase()} LEG</h4>
                            <strong>From:</strong> ${fromHub.name} (${fromHub.id})<br>
                            <strong>To:</strong> ${toHub.name} (${toHub.id})<br>
                            <strong>Shipment:</strong> ${sId}<br>
                            <strong>Distance:</strong> ${arc.distance.toFixed(1)} km<br>
                            <strong>Cost:</strong> ${arc.cost.toFixed(2)} EUR<br>
                            <strong>CO2:</strong> ${arc.emissions.toFixed(2)} kg
                        </div>
                    `;
                    polyline.bindPopup(popupContent);
                    polyline.bindTooltip(`${sId} (${arc.mode}): ${fromHub.id} ➔ ${toHub.id}`, { sticky: true });
                    polyline.addTo(appState.layers.optimizedRoutes);
                }
            }
        });
    });
}

// Fetch list of datasets from API
async function loadDatasetsList() {
    try {
        const response = await fetch('/api/datasets');
        const data = await response.json();
        const select = document.getElementById('dataset-select');
        
        // Remove previous items
        select.innerHTML = '<option value="" disabled selected>Choose a network...</option>';
        
        data.datasets.forEach(filename => {
            const opt = document.createElement('option');
            opt.value = filename;
            opt.textContent = filename;
            select.appendChild(opt);
        });
    } catch (e) {
        console.error("Failed to load datasets list", e);
        logToTerminal("Failed to query available datasets from server.", "error");
    }
}

// Load Selected Dataset
async function loadDataset(filename, customData = null) {
    logToTerminal(`Loading dataset: ${filename || 'Uploaded custom file'}...`);
    const payload = customData ? { custom_data: customData } : { filename: filename };
    
    try {
        const response = await fetch('/api/load_dataset', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        
        const data = await response.json();
        if (data.status === 'success') {
            appState.hubs = data.hubs;
            appState.rawArcs = data.raw_arcs;
            appState.activeDatasetName = data.filename;
            appState.defaultParameters = data.defaults;
            
            // UI Updates
            document.getElementById('current-dataset-name').textContent = data.filename;
            
            // Set stats
            document.getElementById('stat-hubs').textContent = data.stats.num_hubs;
            document.getElementById('stat-templates').textContent = data.stats.num_arc_templates;
            
            let modeCountsStr = [];
            Object.entries(data.stats.mode_counts).forEach(([m, count]) => {
                modeCountsStr.push(`${m[0].toUpperCase()}${m.slice(1)}: ${count}`);
            });
            document.getElementById('stat-modes').textContent = modeCountsStr.join(', ') || 'None';
            document.getElementById('dataset-info').classList.remove('hidden');
            
            // Render Editable Factors Editor
            renderParametersEditor(data.defaults);
            
            // Update Shipment Hub Selects
            updateShipmentHubSelects();
            
            // Map actions
            drawHubsOnMap();
            drawNetworkArcsOnMap();
            
            // Fit map bounds
            const validCoords = appState.hubs.filter(h => h.latitude !== null && h.longitude !== null);
            if (validCoords.length > 0) {
                const latLns = validCoords.map(h => [h.latitude, h.longitude]);
                appState.map.fitBounds(latLns);
            }
            
            logToTerminal(`Dataset loaded successfully. Loaded ${data.hubs.length} hubs and ${data.raw_arcs.length} transport templates.`);
            
            // Reset LNS optimization triggers
            appState.lastResult = null;
            document.getElementById('lns-card').classList.add('hidden');
            document.getElementById('lns-section-divider').classList.add('hidden');
            clearResultsDashboard();
            
        } else {
            throw new Error(data.message);
        }
    } catch (e) {
        console.error("Dataset loading failed", e);
        logToTerminal(`Dataset load error: ${e.message}`, "error");
        alert(`Failed to load network dataset:\n${e.message}`);
    }
}

// Populate Add Shipment Modal Select dropdowns
function updateShipmentHubSelects() {
    const startSelect = document.getElementById('ship-start-hub');
    const endSelect = document.getElementById('ship-end-hub');
    
    const optionsHtml = ['<option value="" disabled selected>Select hub...</option>'];
    appState.hubs.forEach(h => {
        optionsHtml.push(`<option value="${h.id}">${h.name} (${h.id})</option>`);
    });
    
    startSelect.innerHTML = optionsHtml.join('');
    endSelect.innerHTML = optionsHtml.join('');
}

// Render dynamic parameter override forms
function renderParametersEditor(defaults) {
    const container = document.getElementById('cost-factors-container');
    let html = [];
    
    // 1. Mode Factors
    html.push('<div class="panel-subtitle">Variable Mode Factors</div>');
    Object.entries(defaults.mode_factors).forEach(([mode, factor]) => {
        html.push(`
            <div class="cost-factor-mode-box">
                <div class="cost-factor-title ${mode}">${mode}</div>
                <div class="cost-factor-grid">
                    <div class="form-group">
                        <label>Cost / t·km</label>
                        <input type="number" step="0.01" class="factor-input" data-path="mode_factors.${mode}.cost_per_ton_km" value="${factor.cost_per_ton_km}">
                    </div>
                    <div class="form-group">
                        <label>CO2 / t·km (kg)</label>
                        <input type="number" step="0.001" class="factor-input" data-path="mode_factors.${mode}.emissions_kg_per_ton_km" value="${factor.emissions_kg_per_ton_km}">
                    </div>
                </div>
            </div>
        `);
    });
    
    // 2. Capacities
    html.push('<div class="panel-subtitle">Capacities (Tons)</div>');
    html.push('<div class="cost-factor-grid">');
    Object.entries(defaults.capacities).forEach(([key, capacity]) => {
        html.push(`
            <div class="form-group">
                <label>${key[0].toUpperCase()}${key.slice(1)}</label>
                <input type="number" step="1" class="factor-input" data-path="capacities.${key}" value="${capacity}">
            </div>
        `);
    });
    html.push('</div>');
    
    // 3. Default Fixed Costs & Emissions
    html.push('<div class="panel-subtitle">Default Fixed Costs (EUR)</div>');
    html.push('<div class="cost-factor-grid">');
    Object.entries(defaults.default_fixed_costs.transport).forEach(([mode, cost]) => {
        html.push(`
            <div class="form-group">
                <label>Transport ${mode}</label>
                <input type="number" step="1" class="factor-input" data-path="default_fixed_costs.transport.${mode}" value="${cost}">
            </div>
        `);
    });
    html.push(`
        <div class="form-group">
            <label>Transfer</label>
            <input type="number" step="1" class="factor-input" data-path="default_fixed_costs.transfer" value="${defaults.default_fixed_costs.transfer}">
        </div>
        <div class="form-group">
            <label>Waiting</label>
            <input type="number" step="1" class="factor-input" data-path="default_fixed_costs.waiting" value="${defaults.default_fixed_costs.waiting}">
        </div>
    `);
    html.push('</div>');

    html.push('<div class="panel-subtitle">Default Fixed CO2 (kg)</div>');
    html.push('<div class="cost-factor-grid">');
    Object.entries(defaults.default_fixed_emissions.transport).forEach(([mode, co2]) => {
        html.push(`
            <div class="form-group">
                <label>Transport ${mode}</label>
                <input type="number" step="1" class="factor-input" data-path="default_fixed_emissions.transport.${mode}" value="${co2}">
            </div>
        `);
    });
    html.push(`
        <div class="form-group">
            <label>Transfer</label>
            <input type="number" step="1" class="factor-input" data-path="default_fixed_emissions.transfer" value="${defaults.default_fixed_emissions.transfer}">
        </div>
        <div class="form-group">
            <label>Waiting</label>
            <input type="number" step="1" class="factor-input" data-path="default_fixed_emissions.waiting" value="${defaults.default_fixed_emissions.waiting}">
        </div>
    `);
    html.push('</div>');
    
    // 4. Default Variable Factors
    html.push('<div class="panel-subtitle">Default Variable Factors</div>');
    html.push('<div class="cost-factor-grid">');
    const var_keys = [
        ["waiting_cost_per_hour", "Wait Cost / hr"],
        ["waiting_emissions_per_hour", "Wait CO2 / hr"],
        ["transfer_cost_per_ton", "Trans Cost / t"],
        ["transfer_emissions_per_ton", "Trans CO2 / t"]
    ];
    var_keys.forEach(([key, label]) => {
        html.push(`
            <div class="form-group">
                <label>${label}</label>
                <input type="number" step="0.1" class="factor-input" data-path="default_variable_factors.${key}" value="${defaults.default_variable_factors[key]}">
            </div>
        `);
    });
    html.push('</div>');
    
    container.innerHTML = html.join('');
}

// Compile UI overrides back to parameter payload object
function getParametersOverride() {
    if (!appState.defaultParameters) return {};
    
    // Clone defaults
    const result = JSON.parse(JSON.stringify(appState.defaultParameters));
    const inputs = document.querySelectorAll('.factor-input');
    
    inputs.forEach(input => {
        const path = input.dataset.path.split('.');
        const val = parseFloat(input.value) || 0.0;
        
        let curr = result;
        for (let i = 0; i < path.length - 1; i++) {
            curr = curr[path[i]];
        }
        curr[path[path.length - 1]] = val;
    });
    
    return result;
}

// Shipments Table Rendering
function renderShipmentsTable() {
    const tbody = document.getElementById('shipments-tbody');
    if (appState.shipments.length === 0) {
        tbody.innerHTML = '<tr><td colspan="4" class="empty-state">No shipments loaded.</td></tr>';
        return;
    }
    
    let html = [];
    appState.shipments.forEach((ship, idx) => {
        html.push(`
            <tr>
                <td><strong style="color: var(--color-primary);">${ship.id}</strong></td>
                <td>
                    <div style="font-weight: 500;">${ship.start_hub} ➔ ${ship.end_hub}</div>
                    <div style="color: var(--text-muted); font-size: 0.65rem;">Time: ${ship.start_time} - ${ship.deadline} min</div>
                </td>
                <td><span class="weight-badge">${ship.weight} t</span></td>
                <td>
                    <div style="display: flex; gap: 6px; align-items: center;">
                        <input type="checkbox" class="ship-map-toggle" data-idx="${idx}" ${ship._showOnMap ? 'checked' : ''} title="Show query on map">
                        <button class="btn btn-icon-small btn-edit-shipment" data-idx="${idx}" title="Edit shipment">
                            <i data-lucide="edit" style="width: 12px; height: 12px; color: var(--color-primary)"></i>
                        </button>
                        <button class="btn btn-icon-small btn-delete-shipment" data-idx="${idx}" title="Delete shipment">
                            <i data-lucide="trash-2" style="width: 12px; height: 12px; color: var(--color-danger)"></i>
                        </button>
                    </div>
                </td>
            </tr>
        `);
    });
    tbody.innerHTML = html.join('');
    lucide.createIcons();
    
    // Add event listeners to delete buttons
    document.querySelectorAll('.btn-delete-shipment').forEach(btn => {
        btn.addEventListener('click', (e) => {
            const idx = parseInt(e.currentTarget.dataset.idx);
            appState.shipments.splice(idx, 1);
            renderShipmentsTable();
            drawActiveShipmentsOnMap();
        });
    });
    
    // Add event listeners to edit buttons
    document.querySelectorAll('.btn-edit-shipment').forEach(btn => {
        btn.addEventListener('click', (e) => {
            const idx = parseInt(e.currentTarget.dataset.idx);
            openEditShipmentModal(idx);
        });
    });
    
    // Map toggling
    document.querySelectorAll('.ship-map-toggle').forEach(chk => {
        chk.addEventListener('change', (e) => {
            const idx = parseInt(e.target.dataset.idx);
            appState.shipments[idx]._showOnMap = e.target.checked;
            drawActiveShipmentsOnMap();
        });
    });
}

// Log streaming utility
function logToTerminal(message, type = "info") {
    const viewer = document.getElementById('log-viewer');
    const div = document.createElement('div');
    div.className = `log-line ${type}`;
    
    // Print timestamp
    const now = new Date();
    const ts = now.toTimeString().split(' ')[0];
    
    div.innerHTML = `<span style="color: #475569; margin-right: 6px;">[${ts}]</span>${message.replace(/\n/g, '<br>')}`;
    viewer.appendChild(div);
    viewer.scrollTop = viewer.scrollHeight;
}

function clearTerminal() {
    document.getElementById('log-viewer').innerHTML = '';
}

// Clear results dashboard variables
function clearResultsDashboard() {
    document.getElementById('kpi-cost').textContent = '0.00 EUR';
    document.getElementById('kpi-cost-sub').textContent = 'Fixed: 0.00 | Var: 0.00';
    document.getElementById('kpi-emissions').textContent = '0.00 kg';
    document.getElementById('kpi-emissions-sub').textContent = 'Fixed: 0.00 | Var: 0.00';
    document.getElementById('kpi-time').textContent = '0 min';
    document.getElementById('kpi-time-sub').textContent = 'Avg transit time per shipment';
    document.getElementById('kpi-consolidation').textContent = '0%';
    
    document.getElementById('diagnostics-card').classList.add('hidden');
    document.getElementById('routes-empty-state').classList.remove('hidden');
    document.getElementById('routes-accordion').classList.add('hidden');
    document.getElementById('routes-accordion').innerHTML = '';
    
    appState.layers.optimizedRoutes.clearLayers();
}

// Start polling API status during executions
function startStatusPolling(taskId) {
    if (appState.pollInterval) clearInterval(appState.pollInterval);
    appState.activeTaskId = taskId;
    
    document.getElementById('solver-indicator').querySelector('.status-dot').className = 'status-dot active';
    document.getElementById('solver-indicator').querySelector('.status-text').textContent = 'Running';
    document.getElementById('btn-cancel-solve').classList.remove('hidden');
    document.getElementById('solve-progress-container').classList.remove('hidden');
    
    appState.pollInterval = setInterval(async () => {
        try {
            const response = await fetch('/api/status');
            const data = await response.json();
            
            // Check matching task id
            if (data.task_id !== appState.activeTaskId) {
                // Task got cancelled or updated
                stopPollingUI();
                return;
            }
            
            // Update progress bar
            document.getElementById('solve-progress-bar').style.width = `${data.progress}%`;
            document.getElementById('solve-progress-percent').textContent = `${data.progress}%`;
            document.getElementById('solve-progress-text').textContent = data.message || 'Solving...';
            
            // Stream logs
            if (data.logs) {
                const viewer = document.getElementById('log-viewer');
                // Replace console log content (we overwrite to prevent simple appends since API returns whole log)
                viewer.innerHTML = '';
                data.logs.split('\n').forEach(line => {
                    const lineDiv = document.createElement('div');
                    lineDiv.className = 'log-line solver';
                    if (line.includes('❌') || line.includes('error')) lineDiv.className = 'log-line error';
                    if (line.includes('---')) lineDiv.className = 'log-line system';
                    lineDiv.textContent = line;
                    viewer.appendChild(lineDiv);
                });
                viewer.scrollTop = viewer.scrollHeight;
            }
            
            // Update TEN variables if returned
            if (data.ten_stats) {
                document.getElementById('ten-stat-hubs').textContent = data.ten_stats.num_hubs;
                document.getElementById('ten-stat-nodes').textContent = data.ten_stats.num_nodes;
                document.getElementById('ten-stat-edges').textContent = data.ten_stats.num_edges;
                document.getElementById('ten-stat-transport').textContent = data.ten_stats.transport_arcs;
                document.getElementById('ten-stat-transfer').textContent = data.ten_stats.transfer_arcs;
                document.getElementById('ten-stat-waiting').textContent = data.ten_stats.waiting_arcs;
            }
            
            if (data.solver_stats) {
                document.getElementById('solver-var-binary').textContent = data.solver_stats.num_binary_vars;
                document.getElementById('solver-var-integer').textContent = data.solver_stats.num_integer_vars;
                document.getElementById('solver-var-continuous').textContent = data.solver_stats.num_continuous_vars;
                document.getElementById('solver-var-constraints').textContent = data.solver_stats.num_constraints;
            } else {
                document.getElementById('solver-var-binary').textContent = '0';
                document.getElementById('solver-var-integer').textContent = '0';
                document.getElementById('solver-var-continuous').textContent = '0';
                document.getElementById('solver-var-constraints').textContent = '0';
            }
            
            if (!data.is_running) {
                stopPollingUI();
                
                if (data.error) {
                    logToTerminal(`Optimization failed: ${data.error}`, "error");
                    document.getElementById('solver-indicator').querySelector('.status-dot').className = 'status-dot error';
                    document.getElementById('solver-indicator').querySelector('.status-text').textContent = 'Error';
                    alert(`Solve error: ${data.error}`);
                } else if (data.result) {
                    logToTerminal(`Route planning execution completed. Status: ${data.result.status}.`);
                    
                    document.getElementById('solver-indicator').querySelector('.status-dot').className = 'status-dot success';
                    document.getElementById('solver-indicator').querySelector('.status-text').textContent = data.result.status;
                    
                    appState.lastResult = data.result;
                    renderResultsSummary(data.result);
                    
                    // Show LNS card
                    document.getElementById('lns-card').classList.remove('hidden');
                    document.getElementById('lns-section-divider').classList.remove('hidden');
                }
            }
            
        } catch (e) {
            console.error("Error polling solver status", e);
        }
    }, 500);
}

function stopPollingUI() {
    if (appState.pollInterval) {
        clearInterval(appState.pollInterval);
        appState.pollInterval = null;
    }
    appState.activeTaskId = null;
    document.getElementById('btn-cancel-solve').classList.add('hidden');
    document.getElementById('solve-progress-container').classList.add('hidden');
}

// Render final metrics summary
function renderResultsSummary(result) {
    // 1. KPI cards
    document.getElementById('kpi-cost').textContent = `${result.total_cost.toFixed(2)} EUR`;
    document.getElementById('kpi-cost-sub').textContent = `Fixed: ${result.total_fixed_cost.toFixed(2)} | Var: ${result.total_variable_cost.toFixed(2)}`;
    
    document.getElementById('kpi-emissions').textContent = `${result.total_emissions.toFixed(2)} kg`;
    document.getElementById('kpi-emissions-sub').textContent = `Fixed: ${result.total_fixed_emissions.toFixed(2)} | Var: ${result.total_variable_emissions.toFixed(2)}`;
    
    // Average transit time
    const count = Object.keys(result.shipment_routes).length;
    if (count > 0) {
        const avgTime = result.total_time / count;
        document.getElementById('kpi-time').textContent = `${avgTime.toFixed(0)} min`;
        document.getElementById('kpi-time-sub').textContent = `Total transit: ${result.total_time.toFixed(0)} min`;
    } else {
        document.getElementById('kpi-time').textContent = '0 min';
        document.getElementById('kpi-time-sub').textContent = 'No routes generated';
    }
    
    document.getElementById('kpi-consolidation').textContent = result.is_consolidated ? 'Consolidated' : 'Not Consolidated';
    
    // 2. Diagnostics
    const diagCard = document.getElementById('diagnostics-card');
    const diagList = document.getElementById('diagnostics-list');
    if (result.diagnostics && result.diagnostics.length > 0) {
        diagList.innerHTML = result.diagnostics.map(msg => `<li>${msg}</li>`).join('');
        diagCard.classList.remove('hidden');
    } else {
        diagCard.classList.add('hidden');
    }
    
    // 3. Shipment Routes Accordion
    const placeholder = document.getElementById('routes-empty-state');
    const accordion = document.getElementById('routes-accordion');
    
    placeholder.classList.add('hidden');
    accordion.classList.remove('hidden');
    
    let html = [];
    Object.entries(result.shipment_routes).forEach(([sId, rawRoute]) => {
        // Collapse consecutive waiting arcs at the same hub
        const route = [];
        rawRoute.forEach(arc => {
            if (route.length > 0) {
                const last = route[route.length - 1];
                if (arc.arc_type === 'waiting' && last.arc_type === 'waiting' && arc.from_hub === last.from_hub) {
                    last.arrival_min = arc.arrival_min;
                    last.cost += arc.cost;
                    last.emissions += arc.emissions;
                    return;
                }
            }
            route.push({ ...arc });
        });
        
        // Compute stats for this shipment
        const totalDist = route.reduce((acc, arc) => acc + arc.distance, 0);
        const totalCost = route.reduce((acc, arc) => acc + arc.cost, 0);
        const totalCo2 = route.reduce((acc, arc) => acc + arc.emissions, 0);
        
        let pathStr = "No movement";
        if (route.length > 0) {
            const nodes = [route[0].from_hub];
            route.forEach(arc => {
                if (arc.from_hub !== nodes[nodes.length - 1]) {
                    nodes.push(arc.from_hub);
                }
                if (arc.to_hub !== nodes[nodes.length - 1]) {
                    nodes.push(arc.to_hub);
                }
            });
            pathStr = nodes.join(' ➔ ');
        }
        
        html.push(`
            <div class="route-accordion-item">
                <button class="route-trigger" data-shipment-id="${sId}">
                    <div class="route-title-left">
                        <span class="route-ship-id">${sId}</span>
                        <span class="route-path-summary">${pathStr}</span>
                    </div>
                    <div class="route-metrics-right">
                        <span>${totalDist.toFixed(0)} km</span>
                        <span class="route-metric-pill cost">${totalCost.toFixed(1)} EUR</span>
                        <span class="route-metric-pill emissions">${totalCo2.toFixed(1)} kg</span>
                        <i data-lucide="chevron-down" class="route-arrow-icon"></i>
                    </div>
                </button>
                <div class="route-content" id="route-details-${sId}">
                    <div class="route-legs-timeline">
        `);
        
        if (route.length === 0) {
            html.push('<div class="empty-state">No route found. Leg is infeasible.</div>');
        } else {
            // First origin node
            html.push(`
                <div class="route-leg-node start">
                    <span class="leg-time">${route[0].departure_min} min</span>
                    <span class="leg-desc">Origin at <strong>${route[0].from_hub}</strong></span>
                </div>
            `);
            
            route.forEach((arc, legIdx) => {
                let badgeClass = arc.arc_type;
                if (arc.arc_type === 'transport') badgeClass = arc.mode;
                
                let detailsText = '';
                if (arc.arc_type === 'transport') {
                    detailsText = `<span><i data-lucide="map-pin"></i> ${arc.distance.toFixed(1)} km</span>`;
                }
                
                html.push(`
                    <div class="route-leg-arc ${arc.arc_type}">
                        <span class="leg-time" style="padding-top: 4px;">${arc.departure_min} ➔ ${arc.arrival_min}</span>
                        <div>
                            <span class="mode-badge ${badgeClass}">${arc.arc_type === 'transport' ? arc.mode : arc.arc_type}</span>
                            <div class="leg-details">
                                ${detailsText}
                                <span><i data-lucide="euro"></i> ${arc.cost.toFixed(2)}</span>
                                <span><i data-lucide="leaf"></i> ${arc.emissions.toFixed(2)} kg</span>
                                <span><i data-lucide="clock"></i> ${arc.arrival_min - arc.departure_min} min</span>
                            </div>
                        </div>
                    </div>
                `);
                
                // Destination Node
                const isLast = legIdx === route.length - 1;
                const nodeClass = isLast ? 'end' : '';
                html.push(`
                    <div class="route-leg-node ${nodeClass}">
                        <span class="leg-time">${arc.arrival_min} min</span>
                        <span class="leg-desc">${isLast ? 'Final Delivery' : 'Arrived'} at <strong>${arc.to_hub}</strong> (${arc.to_mode})</span>
                    </div>
                `);
            });
        }
        
        html.push(`
                    </div>
                </div>
            </div>
        `);
    });
    
    accordion.innerHTML = html.join('');
    lucide.createIcons();
    
    // Add Accordion click events
    document.querySelectorAll('.route-trigger').forEach(trigger => {
        trigger.addEventListener('click', (e) => {
            const sId = e.currentTarget.dataset.shipmentId;
            const content = document.getElementById(`route-details-${sId}`);
            
            const isActive = e.currentTarget.classList.contains('active');
            
            // Close all
            document.querySelectorAll('.route-trigger').forEach(t => t.classList.remove('active'));
            document.querySelectorAll('.route-content').forEach(c => c.classList.remove('open'));
            
            if (!isActive) {
                e.currentTarget.classList.add('active');
                content.classList.add('open');
                // Draw only this shipment's route on map
                drawOptimizedRoutesOnMap(sId);
            } else {
                // Redraw all routes on map
                drawOptimizedRoutesOnMap(null);
            }
        });
    });
    
    // Draw all routes on map initially
    drawOptimizedRoutesOnMap(null);
}

// Dynamic objective sliders linking
function linkObjectiveSliders() {
    const costInput = document.getElementById('param-weight-cost');
    const timeInput = document.getElementById('param-weight-time');
    const emissionsInput = document.getElementById('param-weight-emissions');
    
    const costVal = document.getElementById('val-weight-cost');
    const timeVal = document.getElementById('val-weight-time');
    const emissionsVal = document.getElementById('val-weight-emissions');
    
    const elements = [costInput, timeInput, emissionsInput];
    const displays = [costVal, timeVal, emissionsVal];
    
    elements.forEach((slider, idx) => {
        slider.addEventListener('input', () => {
            displays[idx].textContent = slider.value;
            validateObjectiveWeights();
        });
    });
}

function validateObjectiveWeights() {
    const c = parseFloat(document.getElementById('param-weight-cost').value);
    const t = parseFloat(document.getElementById('param-weight-time').value);
    const e = parseFloat(document.getElementById('param-weight-emissions').value);
    
    const alertBox = document.getElementById('weights-zero-alert');
    if (c === 0 && t === 0 && e === 0) {
        alertBox.classList.remove('hidden');
        document.getElementById('btn-run-solve').disabled = true;
    } else {
        alertBox.classList.add('hidden');
        document.getElementById('btn-run-solve').disabled = false;
    }
}

// Setup file drop listeners
function setupDragAndDrop() {
    const datasetZone = document.getElementById('dataset-upload-zone');
    const datasetInput = document.getElementById('dataset-file-input');
    
    datasetZone.addEventListener('click', () => datasetInput.click());
    datasetInput.addEventListener('change', (e) => {
        if (e.target.files.length > 0) {
            handleUploadFile(e.target.files[0], 'dataset');
        }
    });
    
    datasetZone.addEventListener('dragover', (e) => {
        e.preventDefault();
        datasetZone.classList.add('dragover');
    });
    datasetZone.addEventListener('dragleave', () => {
        datasetZone.classList.remove('dragover');
    });
    datasetZone.addEventListener('drop', (e) => {
        e.preventDefault();
        datasetZone.classList.remove('dragover');
        if (e.dataTransfer.files.length > 0) {
            handleUploadFile(e.dataTransfer.files[0], 'dataset');
        }
    });
    
    // Shipment zone
    const shipmentZone = document.getElementById('shipment-upload-zone');
    const shipmentInput = document.getElementById('shipment-file-input');
    
    shipmentZone.addEventListener('click', () => shipmentInput.click());
    shipmentInput.addEventListener('change', (e) => {
        if (e.target.files.length > 0) {
            handleUploadFile(e.target.files[0], 'shipments');
        }
    });
}

function handleUploadFile(file, type) {
    const reader = new FileReader();
    reader.onload = function(e) {
        try {
            const json = JSON.parse(e.target.result);
            if (type === 'dataset') {
                loadDataset(null, json);
            } else {
                // Parse shipments
                let loaded = 0;
                const shipmentsArray = Array.isArray(json) ? json : [json];
                shipmentsArray.forEach(raw => {
                    if (raw.id && raw.start_hub && raw.end_hub) {
                        appState.shipments.push({
                            id: String(raw.id),
                            start_hub: String(raw.start_hub),
                            end_hub: String(raw.end_hub),
                            start_time: parseInt(raw.start_time) || 0,
                            deadline: parseInt(raw.deadline) || 1440,
                            weight: parseFloat(raw.weight) || 1.0,
                            max_price: raw.max_price !== undefined ? parseFloat(raw.max_price) : null,
                            max_emissions: raw.max_emissions !== undefined ? parseFloat(raw.max_emissions) : null,
                            objective_weights: raw.objective_weights || null,
                            _showOnMap: false
                        });
                        loaded++;
                    }
                });
                renderShipmentsTable();
                drawActiveShipmentsOnMap();
                logToTerminal(`Imported ${loaded} shipments from file.`);
            }
        } catch (err) {
            alert(`Failed to parse file as JSON:\n${err.message}`);
        }
    };
    reader.readAsText(file);
}

// Modal handling
function initModals() {
    const btnAdd = document.getElementById('btn-add-shipment');
    const modal = document.getElementById('modal-shipment');
    const btnClose = document.getElementById('modal-shipment-close');
    const btnCancel = document.getElementById('btn-cancel-shipment');
    const form = document.getElementById('form-add-shipment');
    const useWeightsChk = document.getElementById('ship-use-custom-weights');
    const weightsContainer = document.getElementById('shipment-weights-container');
    
    useWeightsChk.addEventListener('change', (e) => {
        if (e.target.checked) {
            weightsContainer.classList.remove('hidden');
        } else {
            weightsContainer.classList.add('hidden');
        }
    });
    
    btnAdd.addEventListener('click', () => {
        if (appState.hubs.length === 0) {
            alert("Please load a dataset network first!");
            return;
        }
        appState.editingShipmentIdx = null;
        document.getElementById('modal-shipment-title').textContent = "Add New Shipment";
        document.getElementById('btn-submit-shipment').textContent = "Add Shipment";
        form.reset();
        weightsContainer.classList.add('hidden');
        modal.classList.add('open');
    });
    
    const closeModal = () => {
        modal.classList.remove('open');
        appState.editingShipmentIdx = null;
    };
    
    btnClose.addEventListener('click', closeModal);
    btnCancel.addEventListener('click', closeModal);
    
    form.addEventListener('submit', (e) => {
        e.preventDefault();
        
        const start = document.getElementById('ship-start-hub').value;
        const end = document.getElementById('ship-end-hub').value;
        
        if (start === end) {
            alert("Start and destination hub must differ!");
            return;
        }
        
        // Custom weights
        let obj_weights = null;
        if (useWeightsChk.checked) {
            obj_weights = {
                cost: parseFloat(document.getElementById('ship-weight-cost').value) || 0.0,
                time: parseFloat(document.getElementById('ship-weight-time').value) || 0.0,
                emissions: parseFloat(document.getElementById('ship-weight-emissions').value) || 0.0
            };
        }
        
        const maxPriceVal = document.getElementById('ship-max-price').value;
        const maxEmissionsVal = document.getElementById('ship-max-emissions').value;
        
        const shipmentData = {
            id: document.getElementById('ship-id').value,
            start_hub: start,
            end_hub: end,
            start_time: parseInt(document.getElementById('ship-start-time').value) || 0,
            deadline: parseInt(document.getElementById('ship-deadline').value) || 1440,
            weight: parseFloat(document.getElementById('ship-weight').value) || 1.0,
            max_price: maxPriceVal !== '' ? parseFloat(maxPriceVal) : null,
            max_emissions: maxEmissionsVal !== '' ? parseFloat(maxEmissionsVal) : null,
            objective_weights: obj_weights,
            _showOnMap: appState.editingShipmentIdx !== null ? appState.shipments[appState.editingShipmentIdx]._showOnMap : false
        };
        
        if (appState.editingShipmentIdx !== null) {
            // Update
            appState.shipments[appState.editingShipmentIdx] = shipmentData;
            logToTerminal(`Updated shipment '${shipmentData.id}'.`);
        } else {
            // Create
            appState.shipments.push(shipmentData);
            logToTerminal(`Added shipment '${shipmentData.id}'.`);
        }
        
        renderShipmentsTable();
        drawActiveShipmentsOnMap();
        closeModal();
        
        // Reset form
        form.reset();
        weightsContainer.classList.add('hidden');
    });
}

// Tab handlers
function initTabs() {
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
            document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
            document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
            
            e.currentTarget.classList.add('active');
            const tabId = e.currentTarget.dataset.tab;
            document.getElementById(tabId).classList.add('active');
        });
    });
}

// Initialize Page Controls
function initControls() {
    const datasetSelect = document.getElementById('dataset-select');
    datasetSelect.addEventListener('change', (e) => {
        if (e.target.value) {
            loadDataset(e.target.value);
        }
    });
    
    // Method selector linking
    const methodSelect = document.getElementById('engine-method');
    const timeLimitGroup = document.getElementById('grp-time-limit');
    methodSelect.addEventListener('change', (e) => {
        if (e.target.value === 'solver') {
            timeLimitGroup.classList.remove('hidden');
        } else {
            timeLimitGroup.classList.add('hidden');
        }
    });
    
    // Run Solve Click
    document.getElementById('btn-run-solve').addEventListener('click', async () => {
        if (appState.hubs.length === 0) {
            alert("Load a dataset first!");
            return;
        }
        if (appState.shipments.length === 0) {
            alert("Load or create at least one shipment query!");
            return;
        }
        
        clearTerminal();
        clearResultsDashboard();
        
        const payload = {
            planning_days: parseInt(document.getElementById('param-planning-horizon').value) || 1,
            method: document.getElementById('engine-method').value,
            time_limit_sec: parseFloat(document.getElementById('param-time-limit').value) || 60,
            objective_weights: {
                cost: parseFloat(document.getElementById('param-weight-cost').value) || 0.4,
                time: parseFloat(document.getElementById('param-weight-time').value) || 0.3,
                emissions: parseFloat(document.getElementById('param-weight-emissions').value) || 0.3
            },
            global_factors: getParametersOverride(),
            shipments: appState.shipments.map(s => ({
                id: s.id,
                start_hub: s.start_hub,
                end_hub: s.end_hub,
                start_time: s.start_time,
                deadline: s.deadline,
                weight: s.weight,
                max_price: s.max_price,
                max_emissions: s.max_emissions,
                objective_weights: s.objective_weights
            }))
        };
        
        logToTerminal("Submitting routing run to background engine...");
        
        try {
            const res = await fetch('/api/run', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            });
            const data = await res.json();
            
            if (data.status === 'success') {
                startStatusPolling(data.task_id);
            } else {
                throw new Error(data.message);
            }
        } catch (e) {
            logToTerminal(`Routing run launch failed: ${e.message}`, "error");
            alert(`Launch error: ${e.message}`);
        }
    });
    
    // Cancel solve
    document.getElementById('btn-cancel-solve').addEventListener('click', async () => {
        logToTerminal("Requesting solver termination...");
        try {
            const res = await fetch('/api/cancel');
            stopPollingUI();
            document.getElementById('solver-indicator').querySelector('.status-dot').className = 'status-dot';
            document.getElementById('solver-indicator').querySelector('.status-text').textContent = 'Cancelled';
            logToTerminal("Solve run terminated by user.", "system");
        } catch (e) {
            console.error("Cancel failed", e);
        }
    });
    
    // Run LNS optimization click
    document.getElementById('btn-run-optimize').addEventListener('click', async () => {
        if (!appState.lastResult) return;
        
        const payload = {
            iterations: parseInt(document.getElementById('lns-iterations').value) || 20,
            ruin_fraction: (parseInt(document.getElementById('lns-ruin').value) || 20) / 100.0,
            seed: document.getElementById('lns-seed').value !== "" ? parseInt(document.getElementById('lns-seed').value) : null
        };
        
        logToTerminal("Launching Large Neighborhood Search (LNS) optimization pass...");
        
        try {
            const res = await fetch('/api/optimize', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            });
            const data = await res.json();
            
            if (data.status === 'success') {
                startStatusPolling(data.task_id);
            } else {
                throw new Error(data.message);
            }
        } catch (e) {
            logToTerminal(`LNS optimization run failed: ${e.message}`, "error");
            alert(`LNS optimization error: ${e.message}`);
        }
    });
}

// Window Loader Entry Point
window.addEventListener('DOMContentLoaded', () => {
    lucide.createIcons(); // Initialize Lucide Icons for static sidebar icons!
    initMap();
    loadDatasetsList();
    linkObjectiveSliders();
    setupDragAndDrop();
    initModals();
    initTabs();
    initControls();
    initResizer();
    initLegendToggles();
    initHorizontalResizer();
    initCostFactorsResizer();
    initDashboardResizer();
    initRightResizer();
    initDragAndDropLayout();
});

function initHorizontalResizer() {
    const resizer = document.getElementById('resizer-x');
    const container = document.querySelector('.app-container');
    
    let startX = 0;
    let startSidebarWidth = 0;
    
    function onMouseDown(e) {
        startX = e.clientX;
        startSidebarWidth = document.querySelector('.sidebar').getBoundingClientRect().width;
        resizer.classList.add('dragging');
        
        document.addEventListener('mousemove', onMouseMove);
        document.addEventListener('mouseup', onMouseUp);
        e.preventDefault();
    }
    
    function onMouseMove(e) {
        const deltaX = e.clientX - startX;
        const newWidth = startSidebarWidth + deltaX;
        
        if (newWidth >= 280 && newWidth <= 600) {
            const rightPanel = document.getElementById('right-panel');
            const hasRight = rightPanel && !rightPanel.classList.contains('hidden');
            
            if (hasRight) {
                const rightWidth = rightPanel.getBoundingClientRect().width;
                container.style.gridTemplateColumns = `${newWidth}px 6px 1fr 6px ${rightWidth}px`;
            } else {
                container.style.gridTemplateColumns = `${newWidth}px 6px 1fr`;
            }
            
            if (appState.map) {
                appState.map.invalidateSize({ animate: false });
            }
        }
    }
    
    function onMouseUp() {
        resizer.classList.remove('dragging');
        document.removeEventListener('mousemove', onMouseMove);
        document.removeEventListener('mouseup', onMouseUp);
    }
    
    resizer.addEventListener('mousedown', onMouseDown);
}

function initCostFactorsResizer() {
    const resizer = document.getElementById('resizer-cost-factors');
    const container = document.getElementById('cost-factors-container');
    
    let startY = 0;
    let startHeight = 0;
    
    function onMouseDown(e) {
        startY = e.clientY;
        startHeight = container.getBoundingClientRect().height;
        resizer.classList.add('dragging');
        
        document.addEventListener('mousemove', onMouseMove);
        document.addEventListener('mouseup', onMouseUp);
        e.preventDefault();
    }
    
    function onMouseMove(e) {
        const deltaY = e.clientY - startY;
        const newHeight = startHeight + deltaY;
        
        if (newHeight >= 100 && newHeight <= 600) {
            container.style.height = `${newHeight}px`;
        }
    }
    
    function onMouseUp() {
        resizer.classList.remove('dragging');
        document.removeEventListener('mousemove', onMouseMove);
        document.removeEventListener('mouseup', onMouseUp);
    }
    
    resizer.addEventListener('mousedown', onMouseDown);
}

function openEditShipmentModal(idx) {
    const ship = appState.shipments[idx];
    appState.editingShipmentIdx = idx;
    
    document.getElementById('modal-shipment-title').textContent = `Edit Shipment '${ship.id}'`;
    document.getElementById('btn-submit-shipment').textContent = "Save Changes";
    
    document.getElementById('ship-id').value = ship.id;
    document.getElementById('ship-weight').value = ship.weight;
    document.getElementById('ship-start-hub').value = ship.start_hub;
    document.getElementById('ship-end-hub').value = ship.end_hub;
    document.getElementById('ship-start-time').value = ship.start_time;
    document.getElementById('ship-deadline').value = ship.deadline;
    document.getElementById('ship-max-price').value = ship.max_price !== null ? ship.max_price : '';
    document.getElementById('ship-max-emissions').value = ship.max_emissions !== null ? ship.max_emissions : '';
    
    const useWeightsChk = document.getElementById('ship-use-custom-weights');
    const weightsContainer = document.getElementById('shipment-weights-container');
    
    if (ship.objective_weights) {
        useWeightsChk.checked = true;
        weightsContainer.classList.remove('hidden');
        document.getElementById('ship-weight-cost').value = ship.objective_weights.cost;
        document.getElementById('ship-weight-time').value = ship.objective_weights.time;
        document.getElementById('ship-weight-emissions').value = ship.objective_weights.emissions;
    } else {
        useWeightsChk.checked = false;
        weightsContainer.classList.add('hidden');
        document.getElementById('ship-weight-cost').value = 0.4;
        document.getElementById('ship-weight-time').value = 0.3;
        document.getElementById('ship-weight-emissions').value = 0.3;
    }
    
    document.getElementById('modal-shipment').classList.add('open');
}

function initResizer() {
    const resizer = document.getElementById('resizer-y');
    const grid = document.querySelector('.dashboard-grid');
    
    let startY = 0;
    let startGridHeight = 0;
    
    function onMouseDown(e) {
        startY = e.clientY;
        startGridHeight = grid.getBoundingClientRect().height;
        resizer.classList.add('dragging');
        
        document.addEventListener('mousemove', onMouseMove);
        document.addEventListener('mouseup', onMouseUp);
        e.preventDefault();
    }
    
    function onMouseMove(e) {
        const deltaY = startY - e.clientY;
        const newHeight = startGridHeight + deltaY;
        
        if (newHeight >= 120 && newHeight <= 700) {
            grid.style.height = `${newHeight}px`;
            if (appState.map) {
                appState.map.invalidateSize({ animate: false });
            }
        }
    }
    
    function onMouseUp() {
        resizer.classList.remove('dragging');
        document.removeEventListener('mousemove', onMouseMove);
        document.removeEventListener('mouseup', onMouseUp);
    }
    
    resizer.addEventListener('mousedown', onMouseDown);
}

function initLegendToggles() {
    document.querySelectorAll('.legend-item').forEach(item => {
        item.addEventListener('click', (e) => {
            const mode = e.currentTarget.dataset.mode;
            if (!mode) return;
            
            appState.visibleModes[mode] = !appState.visibleModes[mode];
            if (appState.visibleModes[mode]) {
                e.currentTarget.classList.remove('disabled');
            } else {
                e.currentTarget.classList.add('disabled');
            }
            
            drawNetworkArcsOnMap();
            drawOptimizedRoutesOnMap(null);
        });
    });
}

function initDashboardResizer() {
    const resizer = document.getElementById('resizer-dashboard-x');
    const grid = document.querySelector('.dashboard-grid');
    const leftPanel = grid.children[0];
    
    let startX = 0;
    let startLeftWidth = 0;
    
    function onMouseDown(e) {
        startX = e.clientX;
        startLeftWidth = leftPanel.getBoundingClientRect().width;
        resizer.classList.add('dragging');
        
        document.addEventListener('mousemove', onMouseMove);
        document.addEventListener('mouseup', onMouseUp);
        e.preventDefault();
    }
    
    function onMouseMove(e) {
        const deltaX = e.clientX - startX;
        const newWidth = startLeftWidth + deltaX;
        const gridWidth = grid.getBoundingClientRect().width;
        
        if (newWidth >= 200 && newWidth <= gridWidth * 0.7) {
            const percent = (newWidth / gridWidth) * 100;
            grid.style.gridTemplateColumns = `${percent}% 6px 1fr`;
        }
    }
    
    function onMouseUp() {
        resizer.classList.remove('dragging');
        document.removeEventListener('mousemove', onMouseMove);
        document.removeEventListener('mouseup', onMouseUp);
    }
    
    resizer.addEventListener('mousedown', onMouseDown);
}

function initRightResizer() {
    const resizer = document.getElementById('resizer-right-x');
    const rightPanel = document.getElementById('right-panel');
    const container = document.querySelector('.app-container');
    
    let startX = 0;
    let startWidth = 0;
    
    function onMouseDown(e) {
        startX = e.clientX;
        startWidth = rightPanel.getBoundingClientRect().width;
        resizer.classList.add('dragging');
        
        document.addEventListener('mousemove', onMouseMove);
        document.addEventListener('mouseup', onMouseUp);
        e.preventDefault();
    }
    
    function onMouseMove(e) {
        const deltaX = startX - e.clientX;
        const newWidth = startWidth + deltaX;
        
        if (newWidth >= 280 && newWidth <= 600) {
            rightPanel.style.width = `${newWidth}px`;
            
            const sidebarWidth = document.querySelector('.sidebar').getBoundingClientRect().width;
            container.style.gridTemplateColumns = `${sidebarWidth}px 6px 1fr 6px ${newWidth}px`;
            
            if (appState.map) {
                appState.map.invalidateSize({ animate: false });
            }
        }
    }
    
    function onMouseUp() {
        resizer.classList.remove('dragging');
        document.removeEventListener('mousemove', onMouseMove);
        document.removeEventListener('mouseup', onMouseUp);
    }
    
    resizer.addEventListener('mousedown', onMouseDown);
}

function initDragAndDropLayout() {
    const handle = document.getElementById('routes-box-drag-handle');
    const box = document.getElementById('routes-results-box');
    const rightPanel = document.getElementById('right-panel');
    const rightResizer = document.getElementById('resizer-right-x');
    const rightBody = document.getElementById('right-panel-body');
    const bottomPanel = document.getElementById('results-dashboard-panel');
    const appContainer = document.querySelector('.app-container');
    const dockBackBtn = document.getElementById('btn-dock-back');
    const dockToggleBtn = document.getElementById('btn-dock-toggle');
    
    const originalParent = bottomPanel;
    
    if (dockToggleBtn) {
        dockToggleBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            if (box.parentNode !== rightBody) {
                dockToRight();
            } else {
                dockToBottom();
            }
        });
    }
    
    function dockToRight() {
        rightPanel.classList.remove('hidden');
        rightResizer.classList.remove('hidden');
        appContainer.classList.add('has-right-panel');
        rightBody.appendChild(box);
        
        if (dockToggleBtn) dockToggleBtn.classList.add('hidden');
        
        box.style.height = "100%";
        if (appState.map) appState.map.invalidateSize();
        logToTerminal("Docked Optimal Shipment Routing Paths to right panel.");
    }
    
    function dockToBottom() {
        originalParent.appendChild(box);
        box.style.height = "";
        
        if (dockToggleBtn) dockToggleBtn.classList.remove('hidden');
        
        rightPanel.classList.add('hidden');
        rightResizer.classList.add('hidden');
        appContainer.classList.remove('has-right-panel');
        if (appState.map) appState.map.invalidateSize();
        logToTerminal("Docked Optimal Shipment Routing Paths back to bottom panel.");
    }
    
    if (dockBackBtn) {
        dockBackBtn.addEventListener('click', dockToBottom);
    }
    
    // Drag handle events
    handle.addEventListener('dragstart', (e) => {
        handle.style.cursor = 'grabbing';
        box.classList.add('dragging');
        e.dataTransfer.setData('text/plain', 'routes-box');
        
        if (box.parentNode !== rightBody) {
            rightPanel.classList.remove('hidden');
            rightResizer.classList.remove('hidden');
            appContainer.classList.add('has-right-panel');
            rightPanel.classList.add('drop-target-active');
            if (appState.map) appState.map.invalidateSize();
        } else {
            bottomPanel.classList.add('drop-target-active');
        }
    });
    
    handle.addEventListener('dragend', () => {
        handle.style.cursor = 'grab';
        box.classList.remove('dragging');
        rightPanel.classList.remove('drop-target-active');
        bottomPanel.classList.remove('drop-target-active');
        
        if (box.parentNode !== rightBody) {
            dockToBottom();
        }
    });
    
    // Drop target event registrations
    [rightPanel, rightBody].forEach(elem => {
        if (!elem) return;
        elem.addEventListener('dragover', (e) => {
            e.preventDefault();
            rightPanel.classList.add('drop-target-active');
        });
        elem.addEventListener('dragleave', () => {
            rightPanel.classList.remove('drop-target-active');
        });
        elem.addEventListener('drop', (e) => {
            e.preventDefault();
            rightPanel.classList.remove('drop-target-active');
            if (box.parentNode !== rightBody) {
                dockToRight();
            }
        });
    });
    
    [bottomPanel, originalParent].forEach(elem => {
        if (!elem) return;
        elem.addEventListener('dragover', (e) => {
            e.preventDefault();
            bottomPanel.classList.add('drop-target-active');
        });
        elem.addEventListener('dragleave', () => {
            bottomPanel.classList.remove('drop-target-active');
        });
        elem.addEventListener('drop', (e) => {
            e.preventDefault();
            bottomPanel.classList.remove('drop-target-active');
            if (box.parentNode === rightBody) {
                dockToBottom();
            }
        });
    });
}
