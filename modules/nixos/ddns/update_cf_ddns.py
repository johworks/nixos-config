# This script:
# queries Cloudflare API
# Compares the A record IP to current_ip
# Updates the record if needed

# Imports
import os                           # load env variables
from cloudflare import Cloudflare   # access Cloudflare API
import requests                     # make request to check current IP


def get_current_ip():
    # Use a free service that tells you your IP
    current_ip = requests.get("https://api.ipify.org").text
    print(f"Current IP: {current_ip}")
    return current_ip


def main():

    # Load token info from env vars
    api_token = os.environ.get("CF_API_TOKEN")
    zone_ids = os.environ.get("CF_ZONE_IDS").split(",")

    if not zone_ids:
        print("Missing CF_ZONE_IDS env var")
        exit(1)

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
    for zone_id in zone_ids:
        update_a_record(client, zone_id, current_ip)

    # sleep(some_time)

def update_a_record(client, zone_id, current_ip):

    # Get DNS info
    records = client.dns.records.list(zone_id=zone_id)

    # Look for current A record info
    for record in records.result:
        if record.type == "A":
            print(f"\n{record.name},  A record : {record.content}")

            if record.content == current_ip:
                print("IPs match, no need to change")
            else:
                print("IPs do not match. Taking action to update A record...")

                client.dns.records.update(
                        zone_id=zone_id,
                        dns_record_id=record.id,
                        type="A",
                        name=record.name,
                        content=current_ip,
                        ttl=int(record.ttl),    # keep the same
                        proxied=record.proxied  # keep the same
                )

                print("Record updated successfully!")

if __name__ == "__main__":
    main()
