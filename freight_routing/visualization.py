import folium
from folium.plugins import MarkerCluster
from .data_models import NetworkData, _TimedArc, ArcType

def create_network_map(network_data: NetworkData, route: list[_TimedArc] | tuple[_TimedArc, ...] | None = None) -> folium.Map:
    """Creates an interactive Folium map showing all network hubs and the path of the selected route."""
    hubs = list(network_data.hubs.values())
    if not hubs:
        return folium.Map()
    
    # Calculate map center
    avg_lat = sum(h.latitude for h in hubs) / len(hubs)
    avg_lon = sum(h.longitude for h in hubs) / len(hubs)
    
    m = folium.Map(location=[avg_lat, avg_lon], zoom_start=4)
    
    # Use marker clustering for performance
    marker_cluster = MarkerCluster(name="Hubs").add_to(m)
    
    for hub in hubs:
        tooltip_html = f"<b>{hub.name}</b><br>ID: {hub.id}<br>Supported Modes: {', '.join(hub.supported_modes)}"
        folium.Marker(
            location=[hub.latitude, hub.longitude],
            tooltip=tooltip_html,
            icon=folium.Icon(color="blue", icon="info-sign")
        ).add_to(marker_cluster)
        
    mode_colors = {
        "road": "green",
        "rail": "blue",
        "air": "red",
        "ship": "purple"
    }
    
    if route:
        for arc in route:
            # Visualize only transport arcs (waiting/transfer happen within the same hub)
            if arc.arc_type == ArcType.TRANSPORT:
                from_hub = network_data.hubs.get(arc.from_node.hub_id)
                to_hub = network_data.hubs.get(arc.to_node.hub_id)
                
                if from_hub and to_hub:
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
                            [to_hub.latitude, to_hub.longitude]
                        ],
                        color=color,
                        weight=5,
                        opacity=0.85,
                        popup=popup_html,
                        tooltip=f"{arc.mode.upper()}: {from_hub.id} -> {to_hub.id}"
                    ).add_to(m)
                    
    folium.LayerControl().add_to(m)
    return m
