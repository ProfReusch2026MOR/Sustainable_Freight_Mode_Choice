from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum
from math import isfinite
from typing import ClassVar, TypeAlias


########################################
#               ArcType                #
########################################
class ArcType(StrEnum):
    TRANSFER = "transfer"
    WAITING = "waiting"
    TRANSPORT = "transport"


########################################
#         Helper Normalization         #
########################################
def _normalize_mode(value: str) -> str:
    mode = str(value).strip()
    if not mode:
        raise ValueError("mode must not be empty.")
    return mode


def _normalize_id(value: str, field_name: str) -> str:
    text = str(value).strip()
    if not text:
        raise ValueError(f"{field_name} must not be empty.")
    return text


def _normalize_departure_minutes(
    values: tuple[int, ...] | list[int],
) -> tuple[int, ...]:
    departures = tuple(values)
    if not departures:
        raise ValueError("departure_minutes must not be empty.")
    if any(
        not isinstance(value, int) or value < 0 or value >= 24 * 60
        for value in departures
    ):
        raise ValueError("departure_minutes must contain minutes from 0 to 1439.")
    return departures


def normalize_arc_type(value: ArcType | str) -> ArcType:
    return value if isinstance(value, ArcType) else ArcType(value)


########################################
#                 Hub                  #
########################################
@dataclass(frozen=True)
class Hub:
    id: str
    name: str
    supported_modes: tuple[str, ...]
    latitude: float | None = None
    longitude: float | None = None
    waiting_cost_per_hour: float | None = None
    waiting_emissions_per_hour: float | None = None

    def __post_init__(self) -> None:
        ########################################
        #              validation              #
        ########################################
        object.__setattr__(self, "id", _normalize_id(self.id, "id"))
        object.__setattr__(self, "name", _normalize_id(self.name, "name"))
        modes = tuple(_normalize_mode(mode) for mode in self.supported_modes)
        if not modes:
            raise ValueError("supported_modes must not be empty.")
        object.__setattr__(self, "supported_modes", modes)
        if self.latitude is not None:
            if not (-90.0 <= self.latitude <= 90.0):
                raise ValueError(f"latitude must be between -90 and 90, got {self.latitude}")
        if self.longitude is not None:
            if not (-180.0 <= self.longitude <= 180.0):
                raise ValueError(f"longitude must be between -180 and 180, got {self.longitude}")
        if self.waiting_cost_per_hour is not None:
            if self.waiting_cost_per_hour < 0:
                raise ValueError("waiting_cost_per_hour must not be negative.")
        if self.waiting_emissions_per_hour is not None:
            if self.waiting_emissions_per_hour < 0:
                raise ValueError("waiting_emissions_per_hour must not be negative.")


########################################
#              ModeFactor              #
########################################
@dataclass(frozen=True)
class ModeFactor:
    cost_per_ton_km: float
    emissions_kg_per_ton_km: float

    def __post_init__(self) -> None:
        ########################################
        #              validation              #
        ########################################
        if self.cost_per_ton_km < 0:
            raise ValueError("cost_per_ton_km must not be negative.")
        if self.emissions_kg_per_ton_km < 0:
            raise ValueError("emissions_kg_per_ton_km must not be negative.")


########################################
#           ObjectiveWeights           #
########################################
@dataclass(frozen=True)
class ObjectiveWeights:
    cost: float = 0.4
    time: float = 0.3
    emissions: float = 0.3

    def __post_init__(self) -> None:
        ########################################
        #              validation              #
        ########################################
        for field_name in ("cost", "time", "emissions"):
            value = float(getattr(self, field_name))
            if not isfinite(value):
                raise ValueError(f"{field_name} weight must be finite.")
            if value < 0:
                raise ValueError(f"{field_name} weight must not be negative.")
            object.__setattr__(self, field_name, value)

        if self.cost == 0 and self.time == 0 and self.emissions == 0:
            raise ValueError("At least one objective weight must be positive.")


########################################
#               Shipment               #
########################################
@dataclass(frozen=True)
class Shipment:
    id: str
    start_hub: str
    end_hub: str
    start_time: int
    deadline: int
    max_price: float
    max_emissions: float | None
    weight: float

    def __post_init__(self) -> None:
        ########################################
        #              validation              #
        ########################################
        object.__setattr__(self, "id", _normalize_id(self.id, "id"))
        object.__setattr__(
            self, "start_hub", _normalize_id(self.start_hub, "start_hub")
        )
        object.__setattr__(self, "end_hub", _normalize_id(self.end_hub, "end_hub"))
        if self.start_hub == self.end_hub:
            raise ValueError("Shipment start_hub and end_hub must differ.")
        if self.start_time < 0:
            raise ValueError("start_time must not be negative.")
        if self.deadline < self.start_time:
            raise ValueError("deadline must be greater than or equal to start_time.")
        if self.max_price < 0:
            raise ValueError("max_price must not be negative.")
        if self.max_emissions is not None and self.max_emissions < 0:
            raise ValueError("max_emissions must not be negative.")
        if self.weight <= 0:
            raise ValueError("weight must be positive.")


########################################
#             ArcTemplate              #
########################################
@dataclass(frozen=True)
class ArcTemplate:
    arc_type: ClassVar[ArcType]
    id: str
    duration_min: int
    departure_minutes: tuple[int, ...]
    max_vehicles: int | None
    fixed_cost: float | None
    fixed_emissions: float | None
    capacity: float | None

    def __post_init__(self) -> None:
        ########################################
        #              validation              #
        ########################################
        object.__setattr__(self, "id", _normalize_id(self.id, "id"))
        object.__setattr__(
            self,
            "departure_minutes",
            _normalize_departure_minutes(self.departure_minutes),
        )
        if self.duration_min <= 0:
            raise ValueError("duration_min must be positive.")
        if self.max_vehicles is not None:
            if not isinstance(self.max_vehicles, int) or self.max_vehicles <= 0:
                raise ValueError("max_vehicles must be a positive integer.")
        if self.fixed_cost is not None:
            if self.fixed_cost < 0:
                raise ValueError("fixed_cost must not be negative.")
        if self.fixed_emissions is not None:
            if self.fixed_emissions < 0:
                raise ValueError("fixed_emissions must not be negative.")
        if self.capacity is not None and self.capacity <= 0:
            raise ValueError("capacity must be positive.")


########################################
#         TransportArcTemplate         #
########################################
@dataclass(frozen=True)
class TransportArcTemplate(ArcTemplate):
    arc_type: ClassVar[ArcType] = ArcType.TRANSPORT
    mode: str
    distance: float
    from_hub: str
    to_hub: str
    cost: float | None = None
    emissions: float | None = None

    def __post_init__(self) -> None:
        super().__post_init__()
        ########################################
        #              validation              #
        ########################################
        object.__setattr__(self, "mode", _normalize_mode(self.mode))
        object.__setattr__(self, "from_hub", _normalize_id(self.from_hub, "from_hub"))
        object.__setattr__(self, "to_hub", _normalize_id(self.to_hub, "to_hub"))
        if self.from_hub == self.to_hub:
            raise ValueError("TransportArcTemplate from_hub and to_hub must differ.")
        if self.distance < 0:
            raise ValueError("distance must not be negative.")
        if self.cost is not None and self.cost < 0:
            raise ValueError("cost must not be negative.")
        if self.emissions is not None and self.emissions < 0:
            raise ValueError("emissions must not be negative.")


########################################
#         TransferArcTemplate          #
########################################
@dataclass(frozen=True)
class TransferArcTemplate(ArcTemplate):
    arc_type: ClassVar[ArcType] = ArcType.TRANSFER
    hub: str
    from_mode: str
    to_mode: str
    transfer_cost_per_ton: float | None = None
    transfer_emissions_per_ton: float | None = None

    def __post_init__(self) -> None:
        super().__post_init__()
        ########################################
        #              validation              #
        ########################################
        object.__setattr__(self, "hub", _normalize_id(self.hub, "hub"))
        object.__setattr__(self, "from_mode", _normalize_mode(self.from_mode))
        object.__setattr__(self, "to_mode", _normalize_mode(self.to_mode))
        if self.from_mode == self.to_mode:
            raise ValueError("TransferArcTemplate must change modes.")
        if self.transfer_cost_per_ton is not None:
            if self.transfer_cost_per_ton < 0:
                raise ValueError("transfer_cost_per_ton must not be negative.")
        if self.transfer_emissions_per_ton is not None:
            if self.transfer_emissions_per_ton < 0:
                raise ValueError("transfer_emissions_per_ton must not be negative.")

    @property
    def from_hub(self) -> str:
        return self.hub

    @property
    def to_hub(self) -> str:
        return self.hub


UserArcTemplate: TypeAlias = TransportArcTemplate | TransferArcTemplate


########################################
#            NetworkNode               #
########################################
@dataclass(frozen=True)
class NetworkNode:
    hub_id: str
    mode: str
    time_min: int

    def __str__(self) -> str:
        return f"{self.hub_id}_{self.mode}_{self.time_min}"


########################################
#              _TimedArc               #
########################################
@dataclass(frozen=True)
class _TimedArc:
    from_node: NetworkNode
    to_node: NetworkNode
    mode: str
    arc_type: ArcType
    departure_min: int
    arrival_min: int
    cost: float
    emissions: float
    capacity: float
    max_vehicles: int | None = None
    fixed_cost: float | None = None
    fixed_emissions: float | None = None

    @property
    def duration_min(self) -> int:
        return self.arrival_min - self.departure_min


########################################
#             NetworkData              #
########################################
@dataclass(frozen=True)
class NetworkData:
    hubs: dict[str, Hub]
    mode_factors: dict[str, ModeFactor]
    arc_templates: tuple[UserArcTemplate, ...]
    capacities: dict[str, float]
    default_fixed_costs: FixedFactorDefaults
    default_fixed_emissions: FixedFactorDefaults
    default_variable_factors: VariableFactorDefaults

    def summary(self) -> None:
        """Print a overview of the network dataset."""
        print("==============================")
        print("Summary NetworkData:")
        print(f"hubs={len(self.hubs)}")
        print(f"arcs={len(self.arc_templates)}")
        print(f"modes={len(self.mode_factors)}")
        print("==============================")


@dataclass(frozen=True)
class FixedFactorDefaults:
    transport: dict[str, float]
    waiting: float
    transfer: float

    def __post_init__(self) -> None:
        if self.waiting < 0:
            raise ValueError("waiting must not be negative.")
        if self.transfer < 0:
            raise ValueError("transfer must not be negative.")
        for mode, value in self.transport.items():
            if value < 0:
                raise ValueError(f"transport mode {mode!r} must not be negative.")


@dataclass(frozen=True)
class VariableFactorDefaults:
    waiting_cost_per_hour: float
    waiting_emissions_per_hour: float
    transfer_cost_per_ton: float
    transfer_emissions_per_ton: float

    def __post_init__(self) -> None:
        if self.waiting_cost_per_hour < 0:
            raise ValueError("waiting_cost_per_hour must not be negative.")
        if self.waiting_emissions_per_hour < 0:
            raise ValueError("waiting_emissions_per_hour must not be negative.")
        if self.transfer_cost_per_ton < 0:
            raise ValueError("transfer_cost_per_ton must not be negative.")
        if self.transfer_emissions_per_ton < 0:
            raise ValueError("transfer_emissions_per_ton must not be negative.")


@dataclass(frozen=True)
class RoutingResult:
    status: str
    is_optimal: bool
    total_cost: float
    total_emissions: float
    total_time: float
    shipment_routes: dict[str, tuple[_TimedArc, ...]]
    total_fixed_cost: float = 0.0
    total_variable_cost: float = 0.0
    total_fixed_emissions: float = 0.0
    total_variable_emissions: float = 0.0
