from __future__ import annotations

from pathlib import Path
from typing import Any

import msgspec

from .data_models import (
    ArcType,
    FixedFactorDefaults,
    Hub,
    ModeFactor,
    NetworkData,
    TransferArcTemplate,
    TransportArcTemplate,
    UserArcTemplate,
    VariableFactorDefaults,
    _normalize_mode,
    normalize_arc_type,
)


########################################
#          NetworkDataLoader           #
########################################
class NetworkDataLoader:
    @classmethod
    def from_json(cls, path: str | Path) -> NetworkData:
        """Load network data from a JSON file into validated data model objects."""
        raw_data = msgspec.json.decode(Path(path).read_bytes())

        ########################################
        #              load hubs               #
        ########################################
        hubs = {}
        for raw_hub in raw_data["hubs"]:
            hub = cls._parse_hub(raw_hub)
            if hub.id in hubs:
                raise ValueError(f"Duplicate hub ID found: {hub.id!r}")
            hubs[hub.id] = hub

        ########################################
        #              load arcs               #
        ########################################
        arc_templates = tuple(
            cls._parse_arc_template(raw_arc) for raw_arc in raw_data["arc_templates"]
        )

        ########################################
        #        referential integrity         #
        ########################################
        for arc in arc_templates:
            if isinstance(arc, TransportArcTemplate):
                # Validate hubs exist
                if arc.from_hub not in hubs:
                    raise ValueError(
                        f"Arc {arc.id!r}: from_hub {arc.from_hub!r} does not exist."
                    )
                if arc.to_hub not in hubs:
                    raise ValueError(
                        f"Arc {arc.id!r}: to_hub {arc.to_hub!r} does not exist."
                    )

                # Validate mode is supported by both hubs
                if arc.mode not in hubs[arc.from_hub].supported_modes:
                    raise ValueError(
                        f"Arc {arc.id!r}: mode {arc.mode!r} is not supported by hub {arc.from_hub!r}."
                    )
                if arc.mode not in hubs[arc.to_hub].supported_modes:
                    raise ValueError(
                        f"Arc {arc.id!r}: mode {arc.mode!r} is not supported by hub {arc.to_hub!r}."
                    )

            elif isinstance(arc, TransferArcTemplate):
                # Validate hub exists
                if arc.hub not in hubs:
                    raise ValueError(f"Arc {arc.id!r}: hub {arc.hub!r} does not exist.")

                # Validate both modes of the transfer are supported by the hub
                if arc.from_mode not in hubs[arc.hub].supported_modes:
                    raise ValueError(
                        f"Arc {arc.id!r}: from_mode {arc.from_mode!r} is not supported by hub {arc.hub!r}."
                    )
                if arc.to_mode not in hubs[arc.hub].supported_modes:
                    raise ValueError(
                        f"Arc {arc.id!r}: to_mode {arc.to_mode!r} is not supported by hub {arc.hub!r}."
                    )

        ########################################
        if "default_fixed_costs" not in raw_data:
            raise ValueError("Missing 'default_fixed_costs' in dataset.")
        rfc = raw_data["default_fixed_costs"]
        if "waiting" not in rfc:
            raise ValueError("Missing 'waiting' in 'default_fixed_costs'.")
        if "transfer" not in rfc:
            raise ValueError("Missing 'transfer' in 'default_fixed_costs'.")
        default_fixed_costs = FixedFactorDefaults(
            transport={_normalize_mode(m): float(v) for m, v in rfc.get("transport", {}).items()},
            waiting=float(rfc["waiting"]),
            transfer=float(rfc["transfer"]),
        )

        if "default_fixed_emissions" not in raw_data:
            raise ValueError("Missing 'default_fixed_emissions' in dataset.")
        rfe = raw_data["default_fixed_emissions"]
        if "waiting" not in rfe:
            raise ValueError("Missing 'waiting' in 'default_fixed_emissions'.")
        if "transfer" not in rfe:
            raise ValueError("Missing 'transfer' in 'default_fixed_emissions'.")
        default_fixed_emissions = FixedFactorDefaults(
            transport={_normalize_mode(m): float(v) for m, v in rfe.get("transport", {}).items()},
            waiting=float(rfe["waiting"]),
            transfer=float(rfe["transfer"]),
        )

        if "default_variable_factors" not in raw_data:
            raise ValueError("Missing 'default_variable_factors' in dataset.")
        rvf = raw_data["default_variable_factors"]
        for field in (
            "waiting_cost_per_hour",
            "waiting_emissions_per_hour",
            "transfer_cost_per_ton",
            "transfer_emissions_per_ton",
        ):
            if field not in rvf:
                raise ValueError(f"Missing '{field}' in 'default_variable_factors'.")
        default_variable_factors = VariableFactorDefaults(
            waiting_cost_per_hour=float(rvf["waiting_cost_per_hour"]),
            waiting_emissions_per_hour=float(rvf["waiting_emissions_per_hour"]),
            transfer_cost_per_ton=float(rvf["transfer_cost_per_ton"]),
            transfer_emissions_per_ton=float(rvf["transfer_emissions_per_ton"]),
        )

        ########################################
        #            load capacities           #
        ########################################
        if "capacities" not in raw_data:
            raise ValueError("Missing 'capacities' dictionary in dataset.")
        capacities = {str(k): float(v) for k, v in raw_data["capacities"].items()}
        if "waiting" not in capacities:
            raise ValueError("Missing 'waiting' capacity in capacities.")
        if "transfer" not in capacities:
            raise ValueError("Missing 'transfer' capacity in capacities.")

        return NetworkData(
            hubs=hubs,
            mode_factors={
                _normalize_mode(mode): cls._parse_mode_factor(raw_factor)
                for mode, raw_factor in raw_data["mode_factors"].items()
            },
            arc_templates=arc_templates,
            capacities=capacities,
            default_fixed_costs=default_fixed_costs,
            default_fixed_emissions=default_fixed_emissions,
            default_variable_factors=default_variable_factors,
        )

    ########################################
    #            helper parsers            #
    ########################################

    @staticmethod
    def _parse_hub(raw_hub: dict[str, Any]) -> Hub:
        return Hub(
            id=raw_hub["id"],
            name=raw_hub["name"],
            supported_modes=tuple(raw_hub["supported_modes"]),
            waiting_cost_per_hour=raw_hub.get("waiting_cost_per_hour"),
            waiting_emissions_per_hour=raw_hub.get("waiting_emissions_per_hour"),
        )

    @staticmethod
    def _parse_mode_factor(raw_factor: dict[str, Any]) -> ModeFactor:
        return ModeFactor(
            cost_per_ton_km=raw_factor["cost_per_ton_km"],
            emissions_kg_per_ton_km=raw_factor["emissions_kg_per_ton_km"],
        )

    @classmethod
    def _parse_arc_template(cls, raw_arc: dict[str, Any]) -> UserArcTemplate:
        arc_type = normalize_arc_type(raw_arc["arc_type"])
        common = {
            "id": raw_arc["id"],
            "duration_min": raw_arc["duration_min"],
            "departure_minutes": tuple(raw_arc["departure_minutes"]),
            "max_vehicles": raw_arc.get("max_vehicles"),
            "fixed_cost": raw_arc.get("fixed_cost"),
            "fixed_emissions": raw_arc.get("fixed_emissions"),
            "capacity": raw_arc.get("capacity"),
        }

        if arc_type == ArcType.TRANSPORT:
            return TransportArcTemplate(
                **common,
                mode=raw_arc["mode"],
                distance=raw_arc["dist"],
                from_hub=raw_arc["from"],
                to_hub=raw_arc["to"],
                cost=raw_arc.get("cost"),
                emissions=raw_arc.get("emissions"),
            )

        if arc_type == ArcType.TRANSFER:
            if raw_arc["from"] != raw_arc["to"]:
                raise ValueError(
                    f"{raw_arc['id']}: transfer arcs must stay at one hub."
                )
            return TransferArcTemplate(
                **common,
                hub=raw_arc["from"],
                from_mode=raw_arc["from_mode"],
                to_mode=raw_arc["to_mode"],
                transfer_cost_per_ton=raw_arc.get("transfer_cost_per_ton"),
                transfer_emissions_per_ton=raw_arc.get("transfer_emissions_per_ton"),
            )

        raise ValueError(f"Unsupported user arc_type: {arc_type.value}")
