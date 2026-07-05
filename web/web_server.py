import http.server
import json
import os
import sys
import time
import threading
import traceback
import tempfile
import urllib.parse
from pathlib import Path

# Add workspace root to Python path
sys.path.insert(0, str(Path(__file__).parent.parent.absolute()))

from freight_routing.data_loader import NetworkDataLoader
from freight_routing.data_models import (
    NetworkData,
    Shipment,
    ObjectiveWeights,
    TransportArcTemplate,
    TransferArcTemplate,
    FixedFactorDefaults,
    VariableFactorDefaults,
    ModeFactor,
)
from freight_routing.model import TimeExpandedNetwork, TimeExpandedFreightRoutingModel
from heuristics.dijkstra_router import AStarRouter

# Global task state and cached network data
active_task = {
    "task_id": None,
    "is_running": False,
    "progress": 0,
    "message": "",
    "logs": "",
    "ten_stats": None,
    "solver_stats": None,
    "result": None,
    "error": None,
    "method": None,
    "planning_days": 1,
}

# Cached loaded network data (in-memory)
cached_network_data: NetworkData = None
cached_network_filename: str = None

# Mutex lock for thread-safe state access
task_lock = threading.Lock()


class OutputCapture:
    """Redirects stdout and stderr to a temporary file at C level to capture solver outputs."""

    def __init__(self):
        self.temp_file = None
        self.old_stdout_fd = None
        self.old_stderr_fd = None

    def __enter__(self):
        self.temp_file = tempfile.NamedTemporaryFile(delete=False, mode="w+t")
        # Flush Python buffers
        sys.stdout.flush()
        sys.stderr.flush()
        # Save old descriptors
        self.old_stdout_fd = os.dup(1)
        self.old_stderr_fd = os.dup(2)
        # Duplicate temp file to 1 and 2
        os.dup2(self.temp_file.fileno(), 1)
        os.dup2(self.temp_file.fileno(), 2)
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        # Flush again before restoring
        sys.stdout.flush()
        sys.stderr.flush()
        # Restore descriptors
        os.dup2(self.old_stdout_fd, 1)
        os.dup2(self.old_stderr_fd, 2)
        os.close(self.old_stdout_fd)
        os.close(self.old_stderr_fd)

        # Read captured output
        self.temp_file.seek(0)
        self.output = self.temp_file.read()
        self.temp_file.close()
        try:
            os.unlink(self.temp_file.name)
        except Exception:
            pass


def solve_task_thread(task_id, params):
    global cached_network_data, active_task

    # Progress callback for the heuristic
    def progress_callback(current, total, message):
        with task_lock:
            if active_task["task_id"] == task_id:
                active_task["progress"] = int((current / max(1, total)) * 100)
                active_task["message"] = message

    with task_lock:
        active_task["is_running"] = True
        active_task["progress"] = 0
        active_task["message"] = "Initializing network..."
        active_task["logs"] = ""
        active_task["result"] = None
        active_task["error"] = None
        active_task["ten_stats"] = None
        active_task["solver_stats"] = None
        active_task["method"] = params.get("method")
        active_task["planning_days"] = params.get("planning_days", 1)

    try:
        # Load and override global parameters
        planning_days = int(params.get("planning_days", 1))
        method = params.get("method", "solver")

        # Build shipment objects
        shipment_list = []
        global_obj = params.get(
            "objective_weights", {"cost": 0.4, "time": 0.3, "emissions": 0.3}
        )
        fallback_weights = ObjectiveWeights(
            cost=float(global_obj.get("cost", 0.4)),
            time=float(global_obj.get("time", 0.3)),
            emissions=float(global_obj.get("emissions", 0.3)),
        )

        for raw_ship in params.get("shipments", []):
            ow = raw_ship.get("objective_weights")
            ship_weights = None
            if ow:
                ship_weights = ObjectiveWeights(
                    cost=float(ow.get("cost", 0.4)),
                    time=float(ow.get("time", 0.3)),
                    emissions=float(ow.get("emissions", 0.3)),
                )

            shipment_list.append(
                Shipment(
                    id=str(raw_ship["id"]),
                    start_hub=str(raw_ship["start_hub"]),
                    end_hub=str(raw_ship["end_hub"]),
                    start_time=int(raw_ship["start_time"]),
                    deadline=int(raw_ship["deadline"]),
                    weight=float(raw_ship["weight"]),
                    max_price=float(raw_ship["max_price"])
                    if raw_ship.get("max_price") is not None
                    else None,
                    max_emissions=float(raw_ship["max_emissions"])
                    if raw_ship.get("max_emissions") is not None
                    else None,
                    objective_weights=ship_weights,
                )
            )

        # Global factor overrides
        overrides = params.get("global_factors", {})

        # Resolve fixed factors
        raw_rfc = overrides.get("default_fixed_costs", {})
        default_fixed_costs = FixedFactorDefaults(
            transport={
                str(m): float(v) for m, v in raw_rfc.get("transport", {}).items()
            },
            waiting=float(raw_rfc.get("waiting", 0.0)),
            transfer=float(raw_rfc.get("transfer", 0.0)),
        )

        raw_rfe = overrides.get("default_fixed_emissions", {})
        default_fixed_emissions = FixedFactorDefaults(
            transport={
                str(m): float(v) for m, v in raw_rfe.get("transport", {}).items()
            },
            waiting=float(raw_rfe.get("waiting", 0.0)),
            transfer=float(raw_rfe.get("transfer", 0.0)),
        )

        raw_rvf = overrides.get("default_variable_factors", {})
        default_variable_factors = VariableFactorDefaults(
            waiting_cost_per_hour=float(raw_rvf.get("waiting_cost_per_hour", 0.0)),
            waiting_emissions_per_hour=float(
                raw_rvf.get("waiting_emissions_per_hour", 0.0)
            ),
            transfer_cost_per_ton=float(raw_rvf.get("transfer_cost_per_ton", 0.0)),
            transfer_emissions_per_ton=float(
                raw_rvf.get("transfer_emissions_per_ton", 0.0)
            ),
        )

        # Override mode factors and capacities in the cached network_data
        updated_mode_factors = cached_network_data.mode_factors.copy()
        for mode, val in overrides.get("mode_factors", {}).items():
            updated_mode_factors[mode] = ModeFactor(
                cost_per_ton_km=float(val.get("cost_per_ton_km", 0.0)),
                emissions_kg_per_ton_km=float(val.get("emissions_kg_per_ton_km", 0.0)),
            )

        updated_capacities = cached_network_data.capacities.copy()
        for k, v in overrides.get("capacities", {}).items():
            updated_capacities[k] = float(v)

        network_data_override = NetworkData(
            hubs=cached_network_data.hubs,
            mode_factors=updated_mode_factors,
            arc_templates=cached_network_data.arc_templates,
            capacities=updated_capacities,
            default_fixed_costs=default_fixed_costs,
            default_fixed_emissions=default_fixed_emissions,
            default_variable_factors=default_variable_factors,
        )

        # Build TEN
        with task_lock:
            active_task["message"] = "Generating time-expanded network..."

        ten = TimeExpandedNetwork.build(
            network_data=network_data_override,
            planning_days=planning_days,
            shipments=shipment_list,
            default_fixed_costs=default_fixed_costs,
            default_fixed_emissions=default_fixed_emissions,
            default_variable_factors=default_variable_factors,
        )

        ten_stats = {
            "num_nodes": len(ten.nodes),
            "num_edges": len(ten.all_arcs),
            "num_hubs": len(ten.network_data.hubs),
            "transport_arcs": len(ten.transport_arcs),
            "transfer_arcs": len(ten.transfer_arcs),
            "waiting_arcs": len(ten.waiting_arcs),
        }

        with task_lock:
            active_task["ten_stats"] = ten_stats
            active_task["message"] = "Solving route optimization..."

        result = None
        solver_logs = ""

        if method == "solver":
            model = TimeExpandedFreightRoutingModel(objective_weights=fallback_weights)
            with OutputCapture() as cap:
                result = model.solve(ten, show_progress=True)
            solver_logs = cap.output
            solver_stats = {
                "num_binary_vars": result.num_binary_vars,
                "num_integer_vars": result.num_integer_vars,
                "num_continuous_vars": result.num_continuous_vars,
                "num_constraints": result.num_constraints,
            }
        else:
            router = AStarRouter(objective_weights=fallback_weights)
            logs_buffer = []

            def custom_progress(current, total, msg):
                progress_callback(current, total, msg)
                logs_buffer.append(f"[{int((current / max(1, total)) * 100)}%] {msg}")
                with task_lock:
                    active_task["logs"] = "\n".join(logs_buffer)

            result = router.solve_multiple(
                ten, show_progress=False, progress_callback=custom_progress
            )
            solver_logs = "\n".join(logs_buffer)
            solver_stats = None

        # Serialize result to dict
        serialized_routes = {}
        for s_id, arcs in result.shipment_routes.items():
            serialized_routes[s_id] = [
                {
                    "from_hub": arc.from_node.hub_id,
                    "to_hub": arc.to_node.hub_id,
                    "from_mode": arc.from_node.mode,
                    "to_mode": arc.to_node.mode,
                    "departure_min": arc.departure_min,
                    "arrival_min": arc.arrival_min,
                    "cost": arc.cost,
                    "emissions": arc.emissions,
                    "distance": arc.distance,
                    "arc_type": arc.arc_type.value,
                    "mode": arc.mode,
                }
                for arc in arcs
            ]

        result_dict = {
            "status": result.status,
            "is_optimal": result.is_optimal,
            "objective_value": result.objective_value,
            "total_cost": result.total_cost,
            "total_emissions": result.total_emissions,
            "total_time": result.total_time,
            "total_fixed_cost": result.total_fixed_cost,
            "total_variable_cost": result.total_variable_cost,
            "total_fixed_emissions": result.total_fixed_emissions,
            "total_variable_emissions": result.total_variable_emissions,
            "is_consolidated": result.is_consolidated,
            "diagnostics": result.diagnostics,
            "shipment_routes": serialized_routes,
        }

        with task_lock:
            if active_task["task_id"] == task_id:
                active_task["progress"] = 100
                active_task["message"] = "Complete"
                active_task["logs"] = solver_logs
                active_task["result"] = result_dict
                active_task["solver_stats"] = solver_stats
                active_task["_ten_object"] = ten
                active_task["_raw_result"] = result

    except Exception as e:
        traceback.print_exc()
        with task_lock:
            if active_task["task_id"] == task_id:
                active_task["error"] = str(e)
                active_task["message"] = "Error occurred"
    finally:
        with task_lock:
            if active_task["task_id"] == task_id:
                active_task["is_running"] = False


def optimize_task_thread(task_id, params):
    global active_task

    def progress_callback(current, total, message):
        with task_lock:
            if active_task["task_id"] == task_id:
                active_task["progress"] = int((current / max(1, total)) * 100)
                active_task["message"] = message

    with task_lock:
        active_task["is_running"] = True
        active_task["progress"] = 0
        active_task["message"] = "Starting LNS optimization..."
        active_task["error"] = None

        ten = active_task.get("_ten_object")
        initial_result = active_task.get("_raw_result")

    if ten is None or initial_result is None:
        with task_lock:
            active_task["error"] = "No initial solve result found to optimize."
            active_task["is_running"] = False
        return

    try:
        iterations = int(params.get("iterations", 20))
        ruin_fraction = float(params.get("ruin_fraction", 0.2))
        seed = params.get("seed")
        seed_val = int(seed) if seed is not None and str(seed).strip() != "" else None

        router = AStarRouter(objective_weights=ObjectiveWeights())

        logs_buffer = [
            active_task.get("logs", ""),
            f"\n--- Starting LNS Optimization ({iterations} iterations, ruin fraction {ruin_fraction}) ---",
        ]

        def custom_progress(current, total, msg):
            progress_callback(current, total, msg)
            logs_buffer.append(f"[LNS {int((current / max(1, total)) * 100)}%] {msg}")
            with task_lock:
                active_task["logs"] = "\n".join(logs_buffer)

        result = router.optimize_multiple(
            initial_result=initial_result,
            network=ten,
            iterations=iterations,
            ruin_fraction=ruin_fraction,
            seed=seed_val,
            show_progress=False,
            progress_callback=custom_progress,
        )

        serialized_routes = {}
        for s_id, arcs in result.shipment_routes.items():
            serialized_routes[s_id] = [
                {
                    "from_hub": arc.from_node.hub_id,
                    "to_hub": arc.to_node.hub_id,
                    "from_mode": arc.from_node.mode,
                    "to_mode": arc.to_node.mode,
                    "departure_min": arc.departure_min,
                    "arrival_min": arc.arrival_min,
                    "cost": arc.cost,
                    "emissions": arc.emissions,
                    "distance": arc.distance,
                    "arc_type": arc.arc_type.value,
                    "mode": arc.mode,
                }
                for arc in arcs
            ]

        result_dict = {
            "status": result.status,
            "is_optimal": result.is_optimal,
            "objective_value": result.objective_value,
            "total_cost": result.total_cost,
            "total_emissions": result.total_emissions,
            "total_time": result.total_time,
            "total_fixed_cost": result.total_fixed_cost,
            "total_variable_cost": result.total_variable_cost,
            "total_fixed_emissions": result.total_fixed_emissions,
            "total_variable_emissions": result.total_variable_emissions,
            "is_consolidated": result.is_consolidated,
            "diagnostics": result.diagnostics,
            "shipment_routes": serialized_routes,
        }

        with task_lock:
            if active_task["task_id"] == task_id:
                active_task["progress"] = 100
                active_task["message"] = "Optimization Complete"
                active_task["logs"] = "\n".join(logs_buffer)
                active_task["result"] = result_dict
                active_task["_raw_result"] = result

    except Exception as e:
        traceback.print_exc()
        with task_lock:
            if active_task["task_id"] == task_id:
                active_task["error"] = str(e)
                active_task["message"] = "Optimization Error"
    finally:
        with task_lock:
            if active_task["task_id"] == task_id:
                active_task["is_running"] = False


class RoutePlanningAPIHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self):
        url = urllib.parse.urlparse(self.path)
        path = url.path

        if path == "/api/datasets":
            self.handle_get_datasets()
        elif path == "/api/status":
            self.handle_get_status()
        elif path == "/api/cancel":
            self.handle_post_cancel()
        else:
            self.handle_serve_static(path)

    def do_POST(self):
        url = urllib.parse.urlparse(self.path)
        path = url.path

        content_length = int(self.headers.get("Content-Length", 0))
        post_data = self.rfile.read(content_length)
        params = {}
        if post_data:
            try:
                params = json.loads(post_data.decode("utf-8"))
            except Exception:
                pass

        if path == "/api/load_dataset":
            self.handle_load_dataset(params)
        elif path == "/api/run":
            self.handle_run_routing(params)
        elif path == "/api/optimize":
            self.handle_run_optimization(params)
        else:
            self.send_error(404, "Endpoint not found")

    def handle_serve_static(self, path):
        if path == "/" or path == "":
            path = "/index.html"

        safe_path = path.lstrip("/")
        file_path = Path(__file__).parent.absolute() / safe_path

        if not file_path.exists() or file_path.is_dir():
            self.send_error(404, "File not found")
            return

        content_type = "text/plain"
        suffix = file_path.suffix.lower()
        if suffix == ".html":
            content_type = "text/html"
        elif suffix == ".css":
            content_type = "text/css"
        elif suffix == ".js":
            content_type = "text/javascript"
        elif suffix == ".json":
            content_type = "application/json"
        elif suffix == ".png":
            content_type = "image/png"
        elif suffix == ".jpg" or suffix == ".jpeg":
            content_type = "image/jpeg"
        elif suffix == ".svg":
            content_type = "image/svg+xml"

        try:
            content = file_path.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", content_type)
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(content)
        except Exception as e:
            self.send_error(500, f"Internal server error: {e}")

    def handle_get_datasets(self):
        dataset_dir = Path(__file__).parent.parent.absolute() / "dataset"
        files = []
        if dataset_dir.exists():
            for f in dataset_dir.iterdir():
                if f.suffix == ".json":
                    files.append(f.name)
        files.sort()
        self.send_json_response({"datasets": files})

    def handle_load_dataset(self, params):
        global cached_network_data, cached_network_filename

        filename = params.get("filename")
        custom_data = params.get("custom_data")

        try:
            if custom_data:
                with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as f:
                    f.write(json.dumps(custom_data).encode("utf-8"))
                    tmp_path = f.name
                try:
                    network_data = NetworkDataLoader.from_json(tmp_path)
                    cached_network_filename = "Uploaded Dataset"
                finally:
                    os.unlink(tmp_path)
            elif filename:
                dataset_path = (
                    Path(__file__).parent.parent.absolute() / "dataset" / filename
                )
                if not dataset_path.exists():
                    self.send_error(400, "Dataset file does not exist")
                    return
                network_data = NetworkDataLoader.from_json(dataset_path)
                cached_network_filename = filename
            else:
                self.send_error(400, "No dataset specified")
                return

            cached_network_data = network_data

            raw_transport_arcs = 0
            raw_transfer_arcs = 0
            mode_counts = {}
            for arc in network_data.arc_templates:
                if isinstance(arc, TransportArcTemplate):
                    raw_transport_arcs += 1
                    mode_counts[arc.mode] = mode_counts.get(arc.mode, 0) + 1
                elif isinstance(arc, TransferArcTemplate):
                    raw_transfer_arcs += 1

            hubs_list = []
            for hub in network_data.hubs.values():
                hubs_list.append(
                    {
                        "id": hub.id,
                        "name": hub.name,
                        "supported_modes": list(hub.supported_modes),
                        "latitude": hub.latitude,
                        "longitude": hub.longitude,
                        "waiting_cost_per_hour": hub.waiting_cost_per_hour,
                        "waiting_emissions_per_hour": hub.waiting_emissions_per_hour,
                    }
                )

            defaults = {
                "mode_factors": {
                    mode: {
                        "cost_per_ton_km": factor.cost_per_ton_km,
                        "emissions_kg_per_ton_km": factor.emissions_kg_per_ton_km,
                    }
                    for mode, factor in network_data.mode_factors.items()
                },
                "capacities": network_data.capacities,
                "default_fixed_costs": {
                    "transport": network_data.default_fixed_costs.transport,
                    "waiting": network_data.default_fixed_costs.waiting,
                    "transfer": network_data.default_fixed_costs.transfer,
                },
                "default_fixed_emissions": {
                    "transport": network_data.default_fixed_emissions.transport,
                    "waiting": network_data.default_fixed_emissions.waiting,
                    "transfer": network_data.default_fixed_emissions.transfer,
                },
                "default_variable_factors": {
                    "waiting_cost_per_hour": network_data.default_variable_factors.waiting_cost_per_hour,
                    "waiting_emissions_per_hour": network_data.default_variable_factors.waiting_emissions_per_hour,
                    "transfer_cost_per_ton": network_data.default_variable_factors.transfer_cost_per_ton,
                    "transfer_emissions_per_ton": network_data.default_variable_factors.transfer_emissions_per_ton,
                },
            }

            raw_arcs_list = []
            for arc in network_data.arc_templates:
                if isinstance(arc, TransportArcTemplate):
                    raw_arcs_list.append(
                        {
                            "id": arc.id,
                            "arc_type": "transport",
                            "from": arc.from_hub,
                            "to": arc.to_hub,
                            "mode": arc.mode,
                            "dist": arc.distance,
                            "duration_min": arc.duration_min,
                            "departure_minutes": list(arc.departure_minutes),
                        }
                    )

            self.send_json_response(
                {
                    "status": "success",
                    "filename": cached_network_filename,
                    "stats": {
                        "num_hubs": len(network_data.hubs),
                        "num_arc_templates": len(network_data.arc_templates),
                        "raw_transport_arcs": raw_transport_arcs,
                        "raw_transfer_arcs": raw_transfer_arcs,
                        "mode_counts": mode_counts,
                    },
                    "hubs": hubs_list,
                    "defaults": defaults,
                    "raw_arcs": raw_arcs_list,
                }
            )

        except Exception as e:
            traceback.print_exc()
            self.send_json_response(
                {"status": "error", "message": str(e)}, status_code=500
            )

    def handle_run_routing(self, params):
        global cached_network_data, active_task

        if cached_network_data is None:
            self.send_json_response(
                {"status": "error", "message": "No dataset loaded yet"}, status_code=400
            )
            return

        with task_lock:
            if active_task["is_running"]:
                self.send_json_response(
                    {"status": "error", "message": "Another task is already running"},
                    status_code=400,
                )
                return

            task_id = str(time.time())
            active_task["task_id"] = task_id
            active_task["is_running"] = True

        thread = threading.Thread(target=solve_task_thread, args=(task_id, params))
        thread.daemon = True
        thread.start()

        self.send_json_response({"status": "success", "task_id": task_id})

    def handle_run_optimization(self, params):
        global active_task

        with task_lock:
            if active_task["is_running"]:
                self.send_json_response(
                    {"status": "error", "message": "Another task is already running"},
                    status_code=400,
                )
                return

            if active_task["result"] is None:
                self.send_json_response(
                    {"status": "error", "message": "No results available to optimize"},
                    status_code=400,
                )
                return

            task_id = str(time.time())
            active_task["task_id"] = task_id
            active_task["is_running"] = True

        thread = threading.Thread(target=optimize_task_thread, args=(task_id, params))
        thread.daemon = True
        thread.start()

        self.send_json_response({"status": "success", "task_id": task_id})

    def handle_get_status(self):
        global active_task
        with task_lock:
            status_copy = {
                k: v for k, v in active_task.items() if not k.startswith("_")
            }
        self.send_json_response(status_copy)

    def handle_post_cancel(self):
        global active_task
        with task_lock:
            if active_task["is_running"]:
                active_task["is_running"] = False
                active_task["message"] = "Cancelled by user"
                active_task["task_id"] = None
        self.send_json_response({"status": "cancelled"})

    def send_json_response(self, data, status_code=200):
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode("utf-8"))


def run_server(port=8000):
    server_address = ("", port)
    httpd = http.server.ThreadingHTTPServer(server_address, RoutePlanningAPIHandler)
    print(f"Server running on port {port}...")
    print(f"Open http://localhost:{port} in your browser.")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server.")
        httpd.server_close()


if __name__ == "__main__":
    port = 8000
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except ValueError:
            pass
    run_server(port)
