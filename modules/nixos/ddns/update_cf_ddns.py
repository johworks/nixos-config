# This script:
# queries Cloudflare API
# Compares the A record IP to current_ip
# Updates the record if needed

# Imports
import os                           # load env variables
import json                         # load records file
from cloudflare import Cloudflare   # access Cloudflare API
import requests                     # make request to check current IP


def get_current_ip():
    # Use a free service that tells you your IP
    current_ip = requests.get("https://api.ipify.org").text
    print(f"Current IP: {current_ip}")
    return current_ip


def load_records():
    records_path = os.environ.get("DDNS_RECORDS_PATH")
    if not records_path:
        print("Missing DDNS_RECORDS_PATH env var")
        exit(3)

    try:
        with open(records_path, "r", encoding="utf-8") as handle:
            records = json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        print(f"Unable to read records file {records_path}: {exc}")
        exit(4)

    if not records:
        print("No records configured in DDNS_RECORDS_PATH")
        exit(5)

    return records


def get_zone_id(client, zone_name):
    zones = client.zones.list(name=zone_name)
    if not zones.result:
        print(f"Zone not found: {zone_name}")
        return None
    if len(zones.result) > 1:
        print(f"Multiple zones matched {zone_name}; using first result")
    return zones.result[0].id


def main():

    # Load token info from env vars
    api_token = os.environ.get("CF_API_TOKEN")
    records = load_records()

    if not api_token:
        print("Missing CF_API_TOKEN env var")
        exit(2)

    # Cloudflare information
    client = Cloudflare(api_token=api_token)

    # Get non-static IP
    current_ip = get_current_ip()
    if not current_ip:
        print("Error getting current IP")

    # Put this inside a while loop with configurable wait time
    # while (True):
    # Update all domains
    zone_cache = {}
    for record in records:
        update_a_record(client, record, current_ip, zone_cache)

    # sleep(some_time)


def update_a_record(client, record, current_ip, zone_cache):
    zone_name = record.get("zone_name")
    record_name = record.get("record_name")
    label = record.get("label") or record_name

    if not zone_name or not record_name:
        print(f"Skipping record with missing zone_name/record_name: {record}")
        return

    zone_id = zone_cache.get(zone_name)
    if not zone_id:
        zone_id = get_zone_id(client, zone_name)
        if not zone_id:
            return
        zone_cache[zone_name] = zone_id

    # Get DNS info
    records = client.dns.records.list(zone_id=zone_id, name=record_name, type="A")

    # Look for current A record info
    matches = [item for item in records.result if item.type == "A" and item.name == record_name]
    if not matches:
        print(f"\n{label}: A record not found for {record_name}")
        return
    if len(matches) > 1:
        print(f"\n{label}: multiple A records found for {record_name}; using first result")

    record_item = matches[0]
    print(f"\n{label}, A record: {record_item.content}")

    if record_item.content == current_ip:
        print("IPs match, no need to change")
    else:
        print("IPs do not match. Taking action to update A record...")

        client.dns.records.update(
            zone_id=zone_id,
            dns_record_id=record_item.id,
            type="A",
            name=record_item.name,
            content=current_ip,
            ttl=int(record_item.ttl),    # keep the same
            proxied=record_item.proxied  # keep the same
        )

        print("Record updated successfully!")


if __name__ == "__main__":
    main()
