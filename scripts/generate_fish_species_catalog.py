#!/usr/bin/env python3
"""Generate the bundled Fish Log species catalog from FishBase parquet snapshots.

The app ships a compact JSON catalog so the Fish Log can show every FishBase
species slot immediately, even before the Supabase `species` table has been
fully seeded. Runtime user progress still comes from real catches/user_species.
"""

from __future__ import annotations

import json
import math
import pathlib
import tempfile
from typing import Any

import pyarrow.parquet as pq
import requests


BASE_URL = "https://data.source.coop/cboettig/fishbase/fb/v25.04/parquet"
SOURCE_URL = "https://docs.ropensci.org/rfishbase/reference/fishbase.html"
OUT_PATH = pathlib.Path("ReelRoyale/Resources/FishSpeciesCatalog.json")


def download(name: str) -> pathlib.Path:
    path = pathlib.Path(tempfile.gettempdir()) / f"fishbase_{name}_v25_04.parquet"
    if path.exists():
        return path

    response = requests.get(f"{BASE_URL}/{name}.parquet", timeout=180)
    response.raise_for_status()
    path.write_bytes(response.content)
    return path


def clean(value: Any) -> Any:
    if value is None:
        return None
    if isinstance(value, float) and math.isnan(value):
        return None
    if hasattr(value, "item"):
        return clean(value.item())
    if isinstance(value, str):
        value = " ".join(value.split()).strip()
        return value or None
    return value


def flag(value: Any) -> bool:
    value = clean(value)
    return value in (1, "1", True, "true", "True", "yes", "Yes")


def habitat(row: dict[str, Any]) -> str:
    waters: list[str] = []
    if flag(row.get("Fresh")):
        waters.append("Freshwater")
    if flag(row.get("Brack")):
        waters.append("Brackish")
    if flag(row.get("Saltwater")):
        waters.append("Marine")

    zones: list[str] = []
    zone = clean(row.get("DemersPelag"))
    migration = clean(row.get("AnaCat"))
    if zone and zone.lower() != "unknown":
        zones.append(str(zone).lower())
    if migration and migration.lower() != "unknown":
        zones.append(str(migration).lower())

    base = ", ".join(waters) if waters else "Aquatic"
    if zones:
        return f"{base}; {', '.join(zones)}"
    return base


def rarity(row: dict[str, Any]) -> str:
    length_cm = clean(row.get("Length")) or 0
    vulnerability = clean(row.get("Vulnerability")) or 0
    is_gamefish = flag(row.get("GameFish"))
    importance = (clean(row.get("Importance")) or "").lower()

    if length_cm >= 150 or vulnerability >= 75 or (is_gamefish and length_cm >= 90):
        return "trophy"
    if length_cm >= 75 or vulnerability >= 55 or is_gamefish:
        return "rare"
    if length_cm >= 30 or "commercial" in importance:
        return "uncommon"
    return "common"


def average_inches(row: dict[str, Any]) -> float | None:
    length_cm = clean(row.get("CommonLength")) or clean(row.get("Length"))
    if not length_cm:
        return None
    return round(float(length_cm) * 0.393701, 1)


def main() -> None:
    species_table = pq.read_table(
        download("species"),
        columns=[
            "SpecCode",
            "Genus",
            "Species",
            "FBname",
            "FamCode",
            "Fresh",
            "Brack",
            "Saltwater",
            "DemersPelag",
            "AnaCat",
            "Length",
            "CommonLength",
            "Vulnerability",
            "GameFish",
            "Importance",
        ],
    ).to_pylist()
    families_table = pq.read_table(download("families"), columns=["FamCode", "Family"]).to_pylist()
    families = {clean(row["FamCode"]): clean(row["Family"]) for row in families_table}

    records: list[dict[str, Any]] = []
    for row in species_table:
        row = {key: clean(value) for key, value in row.items()}
        spec_code = row.get("SpecCode")
        genus = row.get("Genus")
        species = row.get("Species")
        if not spec_code or not genus or not species:
            continue
        if genus.lower() == "genus" and species.lower() in {"sp", "spp"}:
            continue

        scientific_name = f"{genus} {species}"
        record: dict[str, Any] = {
            "id": f"fishbase-{spec_code}",
            "name": scientific_name,
            "rarity": rarity(row),
            "habitat": habitat(row),
        }

        common_name = row.get("FBname")
        family = families.get(row.get("FamCode"))
        avg = average_inches(row)
        if common_name and common_name.lower() != scientific_name.lower():
            record["commonName"] = common_name
        if family:
            record["family"] = family
        if avg:
            record["averageSize"] = avg

        records.append(record)

    records.sort(key=lambda item: (item.get("commonName") or item["name"]).lower())
    payload = {
        "source": "FishBase v25.04 parquet snapshot via rOpenSci/source.coop",
        "sourceURL": SOURCE_URL,
        "count": len(records),
        "species": records,
    }

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text(json.dumps(payload, ensure_ascii=True, separators=(",", ":")), encoding="utf-8")
    print(f"Wrote {len(records):,} species to {OUT_PATH}")


if __name__ == "__main__":
    main()
