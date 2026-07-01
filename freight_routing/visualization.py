import folium
from folium.plugins import MarkerCluster
from .data_models import NetworkData, _TimedArc, ArcType, TransportArcTemplate


def create_network_map(
    network_data: NetworkData,
    route: list[_TimedArc] | tuple[_TimedArc, ...] | None = None,
    show_network: bool = True,
) -> folium.Map:
    """Creates an interactive Folium map showing the network hubs, the static mode connections, and the optimized shipment route path.

    Args:
        network_data: The loaded NetworkData object.
        route: Optional shipment routing path to overlay.
        show_network: Whether to display the static mode connections (separated into toggleable layers).
    """
    # Filter hubs that have valid coordinates for map centering and plotting
    hubs = [
        h
        for h in network_data.hubs.values()
        if h.latitude is not None and h.longitude is not None
    ]
    if not hubs:
        return folium.Map()

    # Calculate map center
    avg_lat = sum(h.latitude for h in hubs) / len(hubs)
    avg_lon = sum(h.longitude for h in hubs) / len(hubs)

    # prefer_canvas=True instructs Leaflet to render polylines using HTML5 Canvas rather than SVG,
    # boosting performance significantly for dense datasets.
    m = folium.Map(location=[avg_lat, avg_lon], tiles="CartoDB positron", zoom_start=4, prefer_canvas=True)

    # Use marker clustering for performance
    marker_cluster = MarkerCluster(name="Hubs (Clustered)").add_to(m)

    for hub in hubs:
        tooltip_html = f"<b>{hub.name}</b><br>ID: {hub.id}<br>Supported Modes: {', '.join(hub.supported_modes)}"
        folium.Marker(
            location=[hub.latitude, hub.longitude],
            tooltip=tooltip_html,
            icon=folium.Icon(color="blue", icon="info-sign"),
        ).add_to(marker_cluster)

    mode_colors = {"road": "green", "rail": "blue", "air": "red", "ship": "purple"}

    # 1. Visualize the entire network connections if requested
    if show_network:
        road_group = folium.FeatureGroup(name="Network: Road (LKW)", show=False)
        rail_group = folium.FeatureGroup(name="Network: Rail (Bahn)", show=True)
        air_group = folium.FeatureGroup(name="Network: Air (Flug)", show=True)
        ship_group = folium.FeatureGroup(name="Network: Ship (Schiff)", show=True)

        mode_groups = {
            "road": road_group,
            "rail": rail_group,
            "air": air_group,
            "ship": ship_group,
        }

        plotted_connections = set()

        for template in network_data.arc_templates:
            if isinstance(template, TransportArcTemplate):
                mode = template.mode
                from_id = template.from_hub
                to_id = template.to_hub

                # Check for duplicate connection to keep rendering clean
                conn_key = (min(from_id, to_id), max(from_id, to_id), mode)
                if conn_key in plotted_connections:
                    continue
                plotted_connections.add(conn_key)

                from_hub = network_data.hubs.get(from_id)
                to_hub = network_data.hubs.get(to_id)

                if (
                    from_hub
                    and to_hub
                    and from_hub.latitude is not None
                    and from_hub.longitude is not None
                    and to_hub.latitude is not None
                    and to_hub.longitude is not None
                ):
                    group = mode_groups.get(mode)
                    if group:
                        color = mode_colors.get(mode, "gray")
                        tooltip = f"{mode.upper()}: {from_id} <-> {to_id} ({template.distance:.1f} km)"
                        popup = f"<b>{mode.upper()} Connection</b><br>From: {from_hub.name}<br>To: {to_hub.name}<br>Distance: {template.distance:.1f} km"

                        folium.PolyLine(
                            locations=[
                                [from_hub.latitude, from_hub.longitude],
                                [to_hub.latitude, to_hub.longitude],
                            ],
                            color=color,
                            weight=1.5,
                            opacity=0.4,
                            popup=popup,
                            tooltip=tooltip,
                        ).add_to(group)

        for group in mode_groups.values():
            group.add_to(m)

    # 2. Visualize active shipment route if provided
    if route:
        route_group = folium.FeatureGroup(name="Shipment Route Path", show=True)
        for arc in route:
            # Visualize only transport arcs (waiting/transfer happen within the same hub)
            if arc.arc_type == ArcType.TRANSPORT:
                from_hub = network_data.hubs.get(arc.from_node.hub_id)
                to_hub = network_data.hubs.get(arc.to_node.hub_id)

                if (
                    from_hub
                    and to_hub
                    and from_hub.latitude is not None
                    and from_hub.longitude is not None
                    and to_hub.latitude is not None
                    and to_hub.longitude is not None
                ):
                    color = mode_colors.get(arc.mode, "orange")
                    popup_html = (
                        f"<b>Route Segment</b><br>"
                        f"From: {from_hub.name} ({from_hub.id})<br>"
                        f"To: {to_hub.name} ({to_hub.id})<br>"
                        f"Mode: {arc.mode.upper()}<br>"
                        f"Cost: {arc.cost:.2f} EUR<br>"
                        f"Emissions: {arc.emissions:.2f} kg CO2<br>"
                        f"Duration: {arc.duration_min} min"
                    )

                    folium.PolyLine(
                        locations=[
                            [from_hub.latitude, from_hub.longitude],
                            [to_hub.latitude, to_hub.longitude],
                        ],
                        color=color,
                        weight=6,
                        opacity=0.9,
                        popup=popup_html,
                        tooltip=f"ROUTE ({arc.mode.upper()}): {from_hub.id} -> {to_hub.id}",
                    ).add_to(route_group)
        route_group.add_to(m)

    folium.LayerControl().add_to(m)
    return m
