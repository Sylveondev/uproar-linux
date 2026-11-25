#!/usr/bin/env python3
import json
import os

schema_path = "/usr/share/cinnamon/applets/menu@cinnamon.org/settings-schema.json"
icon_path = "/usr/share/uproar/icon.png"  # Change to your preferred icon path or theme icon name

if os.path.exists(schema_path):
    with open(schema_path, "r") as f:
        data = json.load(f)

    data["menu-icon-custom"]["default"] = True
    data["menu-icon"]["default"] = icon_path

    with open(schema_path, "w") as f:
        json.dump(data, f, indent=4)