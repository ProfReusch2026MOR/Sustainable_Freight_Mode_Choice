import os
import io
import sys
import json
import requests
import pandas as pd
from geopy.distance import geodesic
from dotenv import load_dotenv

# Load API keys from .env file
load_dotenv()

# API Keys
ORS_API_KEY = os.getenv("ORS_API_KEY")
AMADEUS_CLIENT_ID = os.getenv("AMADEUS_CLIENT_ID")
AMADEUS_CLIENT_SECRET = os.getenv("AMADEUS_CLIENT_SECRET")
NAVITIA_API_KEY = os.getenv("NAVITIA_API_KEY")
SEAROUTES_API_KEY = os.getenv("SEAROUTES_API_KEY")

# Output path
OUTPUT_FILE = "dataset/multimodal_network.json"

# Dataset size configuration: "S" (small), "M" (medium), "L" (large/default)
DATASET_SIZE = "L"

# Map dataset sizes to specific parameter settings
SIZE_CONFIGS = {
    "S": {
        "max_hubs": 100,
        "max_cities_per_country": 3,
        "nearest_road_k": 2,
        "nearest_rail_k": 1,
    },
    "M": {
        "max_hubs": 300,
        "max_cities_per_country": 6,
        "nearest_road_k": 3,
        "nearest_rail_k": 2,
    },
    "L": {
        "max_hubs": 1000,
        "max_cities_per_country": 15,
        "nearest_road_k": 3,
        "nearest_rail_k": 2,
    },
}

# Resolve active configuration (using the global DATASET_SIZE, or checking environment)
_selected_size = os.getenv("DATASET_SIZE", DATASET_SIZE).upper()
if _selected_size not in SIZE_CONFIGS:
    _selected_size = "L"

active_config = SIZE_CONFIGS[_selected_size]

MAX_HUBS = active_config["max_hubs"]  # Target number of hubs
ROAD_MAX_DIST_KM = 800  # Max distance for road connections
RAIL_MAX_DIST_KM = 1500  # Max distance for rail connections
NEAREST_ROAD_K = active_config["nearest_road_k"]  # Connect each hub to its k-nearest road neighbors
NEAREST_RAIL_K = active_config["nearest_rail_k"]  # Connect each rail hub to its k-nearest rail neighbors
MAX_CITIES_PER_COUNTRY = active_config["max_cities_per_country"]

# Mode factors as specified by the user
MODE_FACTORS = {
    "road": {
        "cost_per_ton_km": 1.20,
        "emissions_kg_per_ton_km": 0.09,
    },
    "rail": {
        "cost_per_ton_km": 0.70,
        "emissions_kg_per_ton_km": 0.025,
    },
    "air": {
        "cost_per_ton_km": 3.50,
        "emissions_kg_per_ton_km": 0.60,
    },
    "ship": {
        "cost_per_ton_km": 0.40,
        "emissions_kg_per_ton_km": 0.015,
    },
}

CAPACITIES = {
    "road": 40.0,
    "rail": 1000.0,
    "air": 50.0,
    "ship": 8000.0,
    "waiting": 100.0,
    "transfer": 25.0
}

DEFAULT_FIXED_COSTS = {
    "transport": {
        "road": 150.0,
        "rail": 500.0,
        "air": 1200.0,
        "ship": 800.0
    },
    "waiting": 0.0,
    "transfer": 100.0
}

DEFAULT_FIXED_EMISSIONS = {
    "transport": {
        "road": 30.0,
        "rail": 80.0,
        "air": 250.0,
        "ship": 120.0
    },
    "waiting": 0.0,
    "transfer": 10.0
}

DEFAULT_VARIABLE_FACTORS = {
    "waiting_cost_per_hour": 5.0,
    "waiting_emissions_per_hour": 0.0,
    "transfer_cost_per_ton": 50.0,
    "transfer_emissions_per_ton": 5.0
}


# Country to continent mapping for landmass filtering
COUNTRY_TO_CONTINENT = {
    # Europe
    "Germany": "Europe",
    "France": "Europe",
    "Italy": "Europe",
    "United Kingdom": "Europe",
    "Spain": "Europe",
    "Poland": "Europe",
    "Netherlands": "Europe",
    "Belgium": "Europe",
    "Switzerland": "Europe",
    "Austria": "Europe",
    "Sweden": "Europe",
    "Norway": "Europe",
    "Finland": "Europe",
    "Denmark": "Europe",
    "Ireland": "Europe",
    "Portugal": "Europe",
    "Greece": "Europe",
    "Czech Republic": "Europe",
    "Hungary": "Europe",
    "Romania": "Europe",
    "Ukraine": "Europe",
    "Belarus": "Europe",
    "Bulgaria": "Europe",
    "Slovakia": "Europe",
    "Croatia": "Europe",
    "Lithuania": "Europe",
    "Latvia": "Europe",
    "Estonia": "Europe",
    # Asia
    "China": "Asia",
    "Japan": "Asia",
    "India": "Asia",
    "South Korea": "Asia",
    "Indonesia": "Asia",
    "Turkey": "Asia",
    "Saudi Arabia": "Asia",
    "Iran": "Asia",
    "Thailand": "Asia",
    "Vietnam": "Asia",
    "Malaysia": "Asia",
    "Singapore": "Asia",
    "Philippines": "Asia",
    "Pakistan": "Asia",
    "Bangladesh": "Asia",
    "Israel": "Asia",
    "United Arab Emirates": "Asia",
    "Kazakhstan": "Asia",
    "Uzbekistan": "Asia",
    # North America
    "United States": "North America",
    "Canada": "North America",
    "Mexico": "North America",
    # South America
    "Brazil": "South America",
    "Argentina": "South America",
    "Colombia": "South America",
    "Chile": "South America",
    "Peru": "South America",
    "Venezuela": "South America",
    # Africa
    "South Africa": "Africa",
    "Egypt": "Africa",
    "Nigeria": "Africa",
    "Kenya": "Africa",
    "Morocco": "Africa",
    "Algeria": "Africa",
    "Ethiopia": "Africa",
    "Ghana": "Africa",
    # Oceania
    "Australia": "Oceania",
    "New Zealand": "Oceania",
}

# Countries supporting rail networks
RAIL_SUPPORTED_COUNTRIES = {
    "Germany",
    "France",
    "Italy",
    "United Kingdom",
    "Spain",
    "Poland",
    "Netherlands",
    "Belgium",
    "Switzerland",
    "Austria",
    "Sweden",
    "Norway",
    "Denmark",
    "Czech Republic",
    "Hungary",
    "Romania",
    "China",
    "Japan",
    "India",
    "South Korea",
    "United States",
    "Canada",
    "Russia",
    "Ukraine",
    "Kazakhstan",
}


def download_data():
    """Downloads raw datasets and returns DataFrames."""
    print("Downloading datasets...")

    # 1. Cities
    cities_url = "https://raw.githubusercontent.com/bahar/WorldCityLocations/master/World_Cities_Location_table.csv"
    print(f"Fetching cities from {cities_url}")
    r = requests.get(cities_url)
    r.raise_for_status()
    # The file has semicolon sep, no header, and quotes around values
    cities_df = pd.read_csv(io.StringIO(r.text), sep=";", header=None, quotechar='"')
    cities_df.columns = ["id", "country", "name", "lat", "lon", "elevation"]

    # 2. Airports
    airports_url = "https://raw.githubusercontent.com/jpatokal/openflights/master/data/airports.dat"
    print(f"Fetching airports from {airports_url}")
    r = requests.get(airports_url)
    r.raise_for_status()
    airports_df = pd.read_csv(io.StringIO(r.text), header=None)
    # Subset to necessary columns: Name, City, Country, IATA, Lat, Lon
    airports_df = airports_df[[1, 2, 3, 4, 6, 7]]
    airports_df.columns = ["name", "city", "country", "iata", "lat", "lon"]

    # 3. Seaports
    ports_url = "https://raw.githubusercontent.com/blof/LINERLIB/master/data/ports.csv"
    print(f"Fetching ports from {ports_url}")
    r = requests.get(ports_url)
    r.raise_for_status()
    ports_df = pd.read_csv(io.StringIO(r.text), sep="\t")

    return cities_df, airports_df, ports_df


def select_hubs(cities_df, airports_df, ports_df):
    """Selects up to MAX_HUBS important cities and maps airports/ports to them."""
    print(f"Selecting up to {MAX_HUBS} hubs...")

    # Clean city coordinate columns
    cities_df["lat"] = pd.to_numeric(cities_df["lat"], errors="coerce")
    cities_df["lon"] = pd.to_numeric(cities_df["lon"], errors="coerce")
    cities_df = cities_df.dropna(subset=["lat", "lon"])

    # Group by country to get a uniform global distribution
    # We take a max number of cities per country to ensure global coverage
    max_cities_per_country = MAX_CITIES_PER_COUNTRY
    selected_cities = []

    # Sort countries by number of cities to give major nations slightly more weight
    for country, group in cities_df.groupby("country"):
        continent = COUNTRY_TO_CONTINENT.get(country)
        if not continent:
            continue  # Skip countries not in our continent mapping for simplicity

        # Take the first M cities (capitals and major cities are usually listed first)
        group_selected = group.head(max_cities_per_country)
        selected_cities.append(group_selected)

    cities_subset = pd.concat(selected_cities).head(MAX_HUBS)
    print(f"Selected {len(cities_subset)} cities as candidates.")

    # Clean airport & port coordinates
    airports_df["lat"] = pd.to_numeric(airports_df["lat"], errors="coerce")
    airports_df["lon"] = pd.to_numeric(airports_df["lon"], errors="coerce")
    airports_df = airports_df.dropna(subset=["lat", "lon"])
    # Keep only airports with valid 3-letter IATA code
    airports_df = airports_df[airports_df["iata"].str.len() == 3]

    ports_df["Latitude"] = pd.to_numeric(ports_df["Latitude"], errors="coerce")
    ports_df["Longitude"] = pd.to_numeric(ports_df["Longitude"], errors="coerce")
    ports_df = ports_df.dropna(subset=["Latitude", "Longitude"])

    hubs = []
    for _, row in cities_subset.iterrows():
        city_lat = row["lat"]
        city_lon = row["lon"]
        city_name = row["name"]
        country = row["country"]

        # Determine unique ID
        city_id = row["id"]
        # Generate 3-letter code prefix based on city name
        code = "".join([c for c in city_name if c.isalnum()]).upper()[:3]
        hub_id = f"{code}_{city_id}"

        # Check supported modes
        supported_modes = ["road"]  # Road is always supported

        # 1. Rail: Supported in developed networks
        if country in RAIL_SUPPORTED_COUNTRIES:
            supported_modes.append("rail")

        # 2. Air: Check if there is an airport within 50km
        # Simple bounding box pre-filter for speed (+/- 0.45 deg is approx 50km)
        near_airports = airports_df[
            (airports_df["lat"] >= city_lat - 0.45)
            & (airports_df["lat"] <= city_lat + 0.45)
            & (airports_df["lon"] >= city_lon - 0.45)
            & (airports_df["lon"] <= city_lon + 0.45)
        ]

        # Calculate exact distance to find closest airport
        closest_airport = None
        min_air_dist = 50.0
        for _, air in near_airports.iterrows():
            dist = geodesic((city_lat, city_lon), (air["lat"], air["lon"])).km
            if dist < min_air_dist:
                min_air_dist = dist
                closest_airport = air["iata"]

        if closest_airport:
            supported_modes.append("air")

        # 3. Ship: Check if there is a port within 50km
        near_ports = ports_df[
            (ports_df["Latitude"] >= city_lat - 0.45)
            & (ports_df["Latitude"] <= city_lat + 0.45)
            & (ports_df["Longitude"] >= city_lon - 0.45)
            & (ports_df["Longitude"] <= city_lon + 0.45)
        ]

        closest_port = None
        min_port_dist = 50.0
        for _, port in near_ports.iterrows():
            dist = geodesic(
                (city_lat, city_lon), (port["Latitude"], port["Longitude"])
            ).km
            if dist < min_port_dist:
                min_port_dist = dist
                closest_port = port["UNLocode"]

        if closest_port:
            supported_modes.append("ship")

        hubs.append(
            {
                "id": hub_id,
                "name": f"{city_name} Terminal",
                "country": country,
                "continent": COUNTRY_TO_CONTINENT[country],
                "lat": city_lat,
                "lon": city_lon,
                "supported_modes": supported_modes,
                "airport_code": closest_airport,
                "port_code": closest_port,
            }
        )

    return hubs


def calculate_road_arcs(hubs):
    """Calculates road (LKW) connections using OSRM with fallback."""
    print("Calculating LKW connections...")
    arcs = []

    # To reduce API calls, we connect each city to its nearest neighbors on the same continent
    for i, h1 in enumerate(hubs):
        candidates = []
        for j, h2 in enumerate(hubs):
            if i == j:
                continue
            # Same continent check
            if h1["continent"] != h2["continent"]:
                continue

            # Filter by coordinate bounding box before exact geodesic distance calculation
            if abs(h1["lat"] - h2["lat"]) > 7.0 or abs(h1["lon"] - h2["lon"]) > 7.0:
                continue

            dist_geodesic = geodesic((h1["lat"], h1["lon"]), (h2["lat"], h2["lon"])).km
            if dist_geodesic <= ROAD_MAX_DIST_KM:
                candidates.append((dist_geodesic, h2))

        # Connect to K nearest road neighbors
        candidates.sort(key=lambda x: x[0])
        for dist_geo, h2 in candidates[:NEAREST_ROAD_K]:
            dist_km = dist_geo * 1.2  # Default estimation fallback
            duration_min = int(dist_km / 70.0 * 60.0)  # default speed: 70 km/h

            # Query OSRM public API
            url = f"http://router.project-osrm.org/route/v1/driving/{h1['lon']},{h1['lat']};{h2['lon']},{h2['lat']}?overview=false"
            try:
                # Adding a small timeout to keep script responsive
                response = requests.get(url, timeout=3)
                if response.status_code == 200:
                    data = response.json()
                    if "routes" in data and len(data["routes"]) > 0:
                        dist_km = round(data["routes"][0]["distance"] / 1000.0, 1)
                        duration_min = int(data["routes"][0]["duration"] / 60.0)
            except Exception:
                pass  # Fall back silently to geodesic estimate

            # Hour-based schedule for LKW (e.g. hourly)
            departure_minutes = [m * 60 for m in range(24)]

            arcs.append(
                {
                    "id": f"{h1['id']}_{h2['id']}_road",
                    "arc_type": "transport",
                    "from": h1["id"],
                    "to": h2["id"],
                    "mode": "road",
                    "dist": dist_km,
                    "departure_minutes": departure_minutes,
                    "duration_min": duration_min,
                }
            )

    return arcs


def calculate_rail_arcs(hubs):
    """Calculates rail connections with fallback."""
    print("Calculating Bahn connections...")
    arcs = []

    # Filter hubs supporting rail
    rail_hubs = [h for h in hubs if "rail" in h["supported_modes"]]

    for i, h1 in enumerate(rail_hubs):
        candidates = []
        for j, h2 in enumerate(rail_hubs):
            if h1["id"] == h2["id"]:
                continue
            if h1["continent"] != h2["continent"]:
                continue

            dist_geodesic = geodesic((h1["lat"], h1["lon"]), (h2["lat"], h2["lon"])).km
            if dist_geodesic <= RAIL_MAX_DIST_KM:
                candidates.append((dist_geodesic, h2))

        # Connect to K nearest rail neighbors
        candidates.sort(key=lambda x: x[0])
        for dist_geo, h2 in candidates[:NEAREST_RAIL_K]:
            dist_km = round(dist_geo * 1.25, 1)  # Rail circuity factor
            duration_min = (
                int(dist_km / 50.0 * 60.0) + 120
            )  # average 50 km/h + 2 hours buffer

            # If Navitia API key is set, we could query it. Otherwise, use our accurate distance fallback.

            # Scheduled rail departures twice a day: 06:00 (360 min) and 18:00 (1080 min)
            departure_minutes = [360, 1080]

            arcs.append(
                {
                    "id": f"{h1['id']}_{h2['id']}_rail",
                    "arc_type": "transport",
                    "from": h1["id"],
                    "to": h2["id"],
                    "mode": "rail",
                    "dist": dist_km,
                    "departure_minutes": departure_minutes,
                    "duration_min": duration_min,
                }
            )

    return arcs


def calculate_maritime_arcs(hubs):
    """Calculates maritime shipping connections between port hubs."""
    print("Calculating Schiff connections...")
    arcs = []

    # Filter hubs supporting ship
    port_hubs = [h for h in hubs if "ship" in h["supported_modes"]]

    # Connect major ports globally
    for i, h1 in enumerate(port_hubs):
        for j, h2 in enumerate(port_hubs):
            if i == j:
                continue

            dist_geodesic = geodesic((h1["lat"], h1["lon"]), (h2["lat"], h2["lon"])).km
            # Do not connect ports that are extremely close (< 200km) to avoid local ship routes,
            # unless they are key terminals. And limit to global routes.
            if dist_geodesic < 200 or dist_geodesic > 15000:
                continue

            # Connect only to a subset of ports to keep it realistic
            # E.g. connect top international ports across continents
            dist_km = round(dist_geodesic * 1.35, 1)  # maritime path circuity factor
            duration_min = (
                int(dist_km / 22.0 * 60.0) + 720
            )  # average 22 km/h (12 knots) + 12 hrs port time

            # Daily departure for cargo ship
            departure_minutes = [480]  # daily departure at 08:00

            arcs.append(
                {
                    "id": f"{h1['id']}_{h2['id']}_ship",
                    "arc_type": "transport",
                    "from": h1["id"],
                    "to": h2["id"],
                    "mode": "ship",
                    "dist": dist_km,
                    "departure_minutes": departure_minutes,
                    "duration_min": duration_min,
                }
            )

    return arcs


def calculate_aviation_arcs(hubs):
    """Calculates air connections between airport hubs."""
    print("Calculating Flug connections...")
    arcs = []

    air_hubs = [h for h in hubs if "air" in h["supported_modes"]]

    # To reduce API calls and represent reality, we use a hub-and-spoke model.
    # We identify "Super Hubs" (major global nodes) and connect all others to their nearest Super Hub.
    super_hub_names = {
        "Berlin",
        "Hamburg",
        "Frankfurt",
        "München",
        "London",
        "Paris",
        "New York",
        "Singapore",
        "Tokyo",
        "Shanghai",
        "Los Angeles",
        "Chicago",
        "Dubai",
    }

    super_hubs = [h for h in air_hubs if any(sh in h["name"] for sh in super_hub_names)]
    if not super_hubs:
        super_hubs = air_hubs[:10]  # Fallback to first 10 if none match

    for h1 in air_hubs:
        # 1. Connect each air hub to its nearest Super Hub
        closest_super = None
        min_dist = float("inf")
        for sh in super_hubs:
            if h1["id"] == sh["id"]:
                continue
            dist_geo = geodesic((h1["lat"], h1["lon"]), (sh["lat"], sh["lon"])).km
            if dist_geo < min_dist:
                min_dist = dist_geo
                closest_super = sh

        if closest_super:
            dist_km = round(min_dist * 1.05, 1)
            duration_min = (
                int(dist_km / 800.0 * 60.0) + 180
            )  # 800 km/h + 3 hours airport handling
            departure_minutes = [540, 1080]  # departures at 09:00 and 18:00

            # Add bidirectional spoke-hub arcs
            arcs.append(
                {
                    "id": f"{h1['id']}_{closest_super['id']}_air",
                    "arc_type": "transport",
                    "from": h1["id"],
                    "to": closest_super["id"],
                    "mode": "air",
                    "dist": dist_km,
                    "departure_minutes": departure_minutes,
                    "duration_min": duration_min,
                }
            )
            arcs.append(
                {
                    "id": f"{closest_super['id']}_{h1['id']}_air",
                    "arc_type": "transport",
                    "from": closest_super["id"],
                    "to": h1["id"],
                    "mode": "air",
                    "dist": dist_km,
                    "departure_minutes": departure_minutes,
                    "duration_min": duration_min,
                }
            )

    # 2. Connect Super Hubs among each other (Global Spine)
    for i, sh1 in enumerate(super_hubs):
        for j, sh2 in enumerate(super_hubs):
            if i == j:
                continue
            dist_geo = geodesic((sh1["lat"], sh1["lon"]), (sh2["lat"], sh2["lon"])).km
            # Connect only long-haul flights (> 1000 km) to prevent redundancy
            if dist_geo < 1000:
                continue

            dist_km = round(dist_geo * 1.05, 1)
            duration_min = (
                int(dist_km / 800.0 * 60.0) + 240
            )  # 800 km/h + 4 hours airport handling
            departure_minutes = [600, 1200]

            arcs.append(
                {
                    "id": f"{sh1['id']}_{sh2['id']}_air",
                    "arc_type": "transport",
                    "from": sh1["id"],
                    "to": sh2["id"],
                    "mode": "air",
                    "dist": dist_km,
                    "departure_minutes": departure_minutes,
                    "duration_min": duration_min,
                }
            )

    return arcs


def generate_transfer_arcs(hubs):
    """Generates transfer arcs for mode changes at the same hub."""
    print("Generating transfer arcs...")
    arcs = []

    # Transfer durations in minutes
    transfer_durations = {
        ("road", "rail"): 60,
        ("rail", "road"): 60,
        ("road", "air"): 180,
        ("air", "road"): 180,
        ("rail", "air"): 240,
        ("air", "rail"): 240,
        ("road", "ship"): 360,
        ("ship", "road"): 360,
        ("rail", "ship"): 360,
        ("ship", "rail"): 360,
        ("air", "ship"): 480,
        ("ship", "air"): 480,
    }

    for h in hubs:
        modes = h["supported_modes"]
        if len(modes) < 2:
            continue

        for m1 in modes:
            for m2 in modes:
                if m1 == m2:
                    continue

                duration = transfer_durations.get((m1, m2), 120)
                # Transfer windows (e.g. transfers can start at shifts: 05:00, 13:00, 21:00)
                departure_minutes = [300, 780, 1260]

                arcs.append(
                    {
                        "id": f"{h['id']}_{h['id']}_{m1}_{m2}_transfer",
                        "arc_type": "transfer",
                        "from": h["id"],
                        "to": h["id"],
                        "from_mode": m1,
                        "to_mode": m2,
                        "departure_minutes": departure_minutes,
                        "duration_min": duration,
                    }
                )

    return arcs


def generate_sample_shipments(hubs):
    """Generates a list of realistic sample shipments."""
    if len(hubs) < 2:
        return []

    # Connect two hubs (e.g. Berlin to Hamburg, or first two hubs)
    h1 = hubs[0]
    h2 = hubs[1]

    return [
        {
            "id": "S1",
            "start_hub": h1["id"],
            "end_hub": h2["id"],
            "start_time": 240,  # 04:00
            "deadline": 1440,  # end of day
            "max_price": 3000,
            "max_emissions": 120,
            "weight": 1.5,  # tons
        }
    ]


def main():
    global MAX_HUBS, NEAREST_ROAD_K, NEAREST_RAIL_K, MAX_CITIES_PER_COUNTRY

    # Check for size argument in command line or environment variable
    selected_size = os.getenv("DATASET_SIZE", DATASET_SIZE).upper()
    for idx, arg in enumerate(sys.argv):
        if arg in ("--size", "-s") and idx + 1 < len(sys.argv):
            selected_size = sys.argv[idx + 1].upper()
            break

    if selected_size in SIZE_CONFIGS:
        cfg = SIZE_CONFIGS[selected_size]
        MAX_HUBS = cfg["max_hubs"]
        NEAREST_ROAD_K = cfg["nearest_road_k"]
        NEAREST_RAIL_K = cfg["nearest_rail_k"]
        MAX_CITIES_PER_COUNTRY = cfg["max_cities_per_country"]
        actual_size = selected_size
    else:
        actual_size = "L"

    print(f"=== MULTI-MODAL DATA COLLECTION SCRIPT (Size: {actual_size}) ===")

    # Step 1: Download
    cities_df, airports_df, ports_df = download_data()

    # Step 2: Select Hubs
    hubs = select_hubs(cities_df, airports_df, ports_df)

    # Step 3: Calculate Arcs
    road_arcs = calculate_road_arcs(hubs)
    rail_arcs = calculate_rail_arcs(hubs)
    ship_arcs = calculate_maritime_arcs(hubs)
    air_arcs = calculate_aviation_arcs(hubs)

    # Step 4: Transfer Arcs
    transfer_arcs = generate_transfer_arcs(hubs)

    # Combine all arcs
    all_arcs = road_arcs + rail_arcs + ship_arcs + air_arcs + transfer_arcs

    # Step 5: Shipments
    shipments = generate_sample_shipments(hubs)

    # Prepare JSON structure
    json_hubs = []
    for h in hubs:
        json_hubs.append(
            {
                "id": h["id"],
                "name": h["name"],
                "supported_modes": h["supported_modes"],
                "latitude": h["lat"],
                "longitude": h["lon"],
            }
        )

    output_data = {
        "hubs": json_hubs,
        "mode_factors": MODE_FACTORS,
        "capacities": CAPACITIES,
        "default_fixed_costs": DEFAULT_FIXED_COSTS,
        "default_fixed_emissions": DEFAULT_FIXED_EMISSIONS,
        "default_variable_factors": DEFAULT_VARIABLE_FACTORS,
        "arc_templates": all_arcs,
        "shipments": shipments,
    }

    # Write to output file
    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(output_data, f, indent=4, ensure_ascii=False)

    print("=== SUCCESS ===")
    print(f"Exported data to {OUTPUT_FILE}")
    print(f"Total Hubs: {len(json_hubs)}")
    print(
        f"Total Arcs: {len(all_arcs)} (Road: {len(road_arcs)}, Rail: {len(rail_arcs)}, Ship: {len(ship_arcs)}, Air: {len(air_arcs)}, Transfer: {len(transfer_arcs)})"
    )


if __name__ == "__main__":
    main()
