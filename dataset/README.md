# Multimodal Network Dataset Specification

This document describes the JSON schema and validation rules for the multimodal network dataset (`multimodal_network.json`). The dataset represents the physical infrastructure, default cost/emissions factors, and schedules used by the time-expanded freight routing solver.

---

## Root Structure

A conforming dataset JSON must contain the following top-level keys:

| Key | Type | Required? | Description |
| :--- | :--- | :--- | :--- |
| `hubs` | List of Objects | **Yes** | List of all terminals, ports, airports, and hubs in the network. |
| `mode_factors` | Object (Dict) | **Yes** | Variable cost and emissions factors per transport mode. |
| `capacities` | Object (Dict) | **Yes** | Default vehicle/transfer/waiting capacity limits (in tons). |
| `arc_templates` | List of Objects | **Yes** | Connection templates that define how modes interact between or within hubs. |
| `default_fixed_costs` | Object | **Yes** | Default fixed costs for launching a vehicle or transfer/waiting process. |
| `default_fixed_emissions`| Object | **Yes** | Default fixed emissions for launching a vehicle or transfer/waiting process. |
| `default_variable_factors`| Object | **Yes** | Fallback variable factors for waiting hourly and transfer per ton. |

---

## 1. Hubs (`hubs`)

Each hub represents a node in the physical transportation network (e.g., an airport, a seaport, or a rail terminal).

```json
{
  "id": "BER",
  "name": "Berlin Brandenburger Airport",
  "supported_modes": ["road", "air"],
  "waiting_cost_per_hour": 4.5,
  "waiting_emissions_per_hour": 0.1
}
```

### Validation Rules:
* `id`: **Required**. String, must not be empty. Must be unique.
* `name`: **Required**. String, must not be empty.
* `supported_modes`: **Required**. List of strings. Must contain at least one mode.
* `waiting_cost_per_hour`: *Optional*. Float $\ge 0$. Falls back to `default_variable_factors.waiting_cost_per_hour` (default `5.0`) if omitted.
* `waiting_emissions_per_hour`: *Optional*. Float $\ge 0$. Falls back to `default_variable_factors.waiting_emissions_per_hour` (default `0.0`) if omitted.

---

## 2. Mode Factors (`mode_factors`)

Specifies the variable cost and emissions per ton-kilometer for each transport mode.

```json
"mode_factors": {
  "road": {
    "cost_per_ton_km": 0.15,
    "emissions_kg_per_ton_km": 0.062
  },
  "air": {
    "cost_per_ton_km": 1.45,
    "emissions_kg_per_ton_km": 0.613
  }
}
```

### Validation Rules:
* Keys represent the mode names (e.g., `"road"`, `"air"`, `"rail"`, `"ship"`).
* `cost_per_ton_km`: **Required**. Float $\ge 0$.
* `emissions_kg_per_ton_km`: **Required**. Float $\ge 0$.

---

## 3. Capacities (`capacities`)

Defines default capacities (in metric tons) for different transport modes and internal processes.

```json
"capacities": {
  "road": 10.0,
  "rail": 40.0,
  "air": 5.0,
  "ship": 80.0,
  "waiting": 100.0,
  "transfer": 25.0
}
```

### Validation Rules:
* Must contain `"waiting"` (float $> 0$) defining the default waiting capacity.
* Must contain `"transfer"` (float $> 0$) defining the default transfer capacity.
* Other keys map transport modes to their default vehicle capacity (e.g., road truck capacity of 10 tons).

> [!NOTE]
> Capacity values can be overridden individually on each connection template in `arc_templates`.

---

## 4. Required Fixed and Variable Defaults

### `default_fixed_costs` & `default_fixed_emissions` (Required)
Defines default fixed costs / emissions per dispatch (e.g., hiring a truck, starting a train, or booking a transfer).
```json
"default_fixed_costs": {
  "transport": {
    "road": 150.0,
    "rail": 800.0,
    "air": 2500.0
  },
  "waiting": 0.0,
  "transfer": 50.0
}
```
* `transport`: Object mapping mode string to float $\ge 0$.
* `waiting`: Float $\ge 0$.
* `transfer`: Float $\ge 0$.

### `default_variable_factors` (Required)
Defines default variable factors for waiting (hourly) and transfer (per ton):
```json
"default_variable_factors": {
  "waiting_cost_per_hour": 5.0,
  "waiting_emissions_per_hour": 0.0,
  "transfer_cost_per_ton": 50.0,
  "transfer_emissions_per_ton": 5.0
}
```
* `waiting_cost_per_hour`: Float $\ge 0$.
* `waiting_emissions_per_hour`: Float $\ge 0$.
* `transfer_cost_per_ton`: Float $\ge 0$.
* `transfer_emissions_per_ton`: Float $\ge 0$.

---

## 5. Arc Templates (`arc_templates`)

Arc templates represent connection routes between hubs. There are two types: **transport** (moving between hubs) and **transfer** (switching modes at a hub).

### Common Fields for All Templates:
* `id`: **Required**. String, must not be empty and must be unique.
* `arc_type`: **Required**. String, must be exactly `"transport"` or `"transfer"`.
* `duration_min`: **Required**. Integer $> 0$. Duration of the connection in minutes.
* `departure_minutes`: **Required**. List of integers. Daily departure schedule times (minutes from midnight, `0` to `1439`).
* `max_vehicles`: *Optional*. Integer $> 0$. Maximum vehicle dispatches permitted on this template per schedule event.
* `fixed_cost`: *Optional*. Float $\ge 0$. Overrides the default fixed cost factor.
* `fixed_emissions`: *Optional*. Float $\ge 0$. Overrides the default fixed emissions factor.
* `capacity`: *Optional*. Float $> 0$. Connection-specific capacity override (in tons), overriding the global defaults in `capacities`.

---

### Type A: Transport Arcs (`arc_type == "transport"`)
Defines physical travel between two distinct hubs.

```json
{
  "id": "T_BER_MUC_ROAD",
  "arc_type": "transport",
  "from": "BER",
  "to": "MUC",
  "mode": "road",
  "dist": 505.0,
  "duration_min": 360,
  "departure_minutes": [360, 720, 1080],
  "capacity": 12.0
}
```

* `from`: **Required**. Hub ID. Must exist in `hubs`. The mode must be supported by the origin hub.
* `to`: **Required**. Hub ID. Must exist in `hubs`. The mode must be supported by the destination hub. Must differ from `from`.
* `mode`: **Required**. String. Transport mode (e.g. `"road"`).
* `dist`: **Required**. Float $\ge 0$. Distance in kilometers.
* `cost`: *Optional*. Float $\ge 0$. Custom variable cost per ton. (If omitted, calculated as `dist * mode_factors[mode].cost_per_ton_km`).
* `emissions`: *Optional*. Float $\ge 0$. Custom variable emissions per ton. (If omitted, calculated as `dist * mode_factors[mode].emissions_kg_per_ton_km`).

---

### Type B: Transfer Arcs (`arc_type == "transfer"`)
Defines mode switching processes within a single hub.

```json
{
  "id": "X_BER_ROAD_AIR",
  "arc_type": "transfer",
  "from": "BER",
  "to": "BER",
  "from_mode": "road",
  "to_mode": "air",
  "duration_min": 120,
  "departure_minutes": [0, 240, 480, 720, 960, 1200],
  "transfer_cost_per_ton": 45.0,
  "transfer_emissions_per_ton": 3.0
}
```

* `from`: **Required**. Hub ID. Must exist in `hubs`.
* `to`: **Required**. Hub ID. Must match `from`.
* `from_mode`: **Required**. String. Origin mode. Must be supported by the hub.
* `to_mode`: **Required**. String. Destination mode. Must be supported by the hub. Must differ from `from_mode`.
* `transfer_cost_per_ton`: *Optional*. Float $\ge 0$. Custom cost per ton. Falls back to `default_variable_factors.transfer_cost_per_ton` if omitted.
* `transfer_emissions_per_ton`: *Optional*. Float $\ge 0$. Custom emissions per ton. Falls back to `default_variable_factors.transfer_emissions_per_ton` if omitted.

---

## Minimal Example Dataset

Here is a minimal conforming JSON dataset:

```json
{
  "hubs": [
    {
      "id": "BER",
      "name": "Berlin Hub",
      "supported_modes": ["road", "rail"]
    },
    {
      "id": "MUC",
      "name": "Munich Hub",
      "supported_modes": ["road", "rail"]
    }
  ],
  "mode_factors": {
    "road": {
      "cost_per_ton_km": 0.15,
      "emissions_kg_per_ton_km": 0.05
    },
    "rail": {
      "cost_per_ton_km": 0.05,
      "emissions_kg_per_ton_km": 0.01
    }
  },
  "capacities": {
    "road": 10.0,
    "rail": 40.0,
    "waiting": 100.0,
    "transfer": 25.0
  },
  "default_fixed_costs": {
    "transport": {
      "road": 100.0,
      "rail": 500.0
    },
    "waiting": 0.0,
    "transfer": 20.0
  },
  "default_fixed_emissions": {
    "transport": {
      "road": 20.0,
      "rail": 100.0
    },
    "waiting": 0.0,
    "transfer": 2.0
  },
  "default_variable_factors": {
    "waiting_cost_per_hour": 5.0,
    "waiting_emissions_per_hour": 0.0,
    "transfer_cost_per_ton": 50.0,
    "transfer_emissions_per_ton": 5.0
  },
  "arc_templates": [
    {
      "id": "T_BER_MUC_ROAD",
      "arc_type": "transport",
      "from": "BER",
      "to": "MUC",
      "mode": "road",
      "dist": 500.0,
      "duration_min": 360,
      "departure_minutes": [480, 1080]
    },
    {
      "id": "X_BER_ROAD_RAIL",
      "arc_type": "transfer",
      "from": "BER",
      "to": "BER",
      "from_mode": "road",
      "to_mode": "rail",
      "duration_min": 60,
      "departure_minutes": [0, 360, 720, 1080]
    }
  ]
}
```
