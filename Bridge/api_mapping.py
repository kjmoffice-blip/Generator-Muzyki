"""Adapt the installed Gradio schema without hard-coding parameter indexes."""


def generation_arguments(schema, request):
    """Map supported user values and safe defaults to live endpoint names."""
    parameters = schema.get("parameters", [])
    labels = {p["label"]: p for p in parameters}
    required = {"Music Caption", "Lyrics", "BPM (Beats Per Minute)",
                "Audio Duration (seconds)", "Vocal Language", "Audio Format", "Think"}
    missing = required - labels.keys()
    if missing:
        raise ValueError("Niekompatybilne API ACE-Step: " + ", ".join(sorted(missing)))
    overrides = {
        "Music Caption": request["caption"],
        "Lyrics": "[Instrumental]" if request["instrumental"] else request["lyrics"],
        "BPM (Beats Per Minute)": request["bpm"] or None,
        "Audio Duration (seconds)": request["duration"], "Batch Size": 1,
        "Vocal Language": "unknown" if request["instrumental"] else request["language"],
        "DiT Inference Steps": request["steps"], "Random Seed": request["seed"] < 0,
        "Seed": str(request["seed"]), "Reference Audio": request.get("reference_audio"), "Source Audio": None,
        "LM Codes Hints": "", "Track Name": None, "Track Names": [],
        "source caption": "", "source lyrics": "", "Think": request["thinking"],
        "Audio Format": request["format"], "MP3 Bitrate": request["bitrate"],
        "MP3 Sample Rate": 48000, "AutoGen": False, "Auto Score": False,
        "Auto LRC": False, "Edit": False,
    }
    args = {}
    for parameter in parameters:
        label = parameter["label"]
        if label in overrides:
            value = overrides[label]
        elif parameter.get("parameter_has_default"):
            value = parameter.get("parameter_default")
        else:
            raise ValueError(f"Nieznany wymagany parametr silnika: {label}.")
        choices = parameter.get("type", {}).get("enum")
        if choices and value is not None and value not in choices:
            raise ValueError(f"Silnik nie obsługuje wartości {value!r} dla {label}.")
        args[parameter["parameter_name"]] = value
    return args


def unpack(value):
    """Read Gradio update envelopes while preserving plain file values."""
    if isinstance(value, dict) and value.get("__type__") == "update":
        return value.get("value")
    return value


def output_by_label(schema, result, label):
    """Locate one result by the schema's label, not its numeric position."""
    for index, field in enumerate(schema.get("returns", [])):
        if field.get("label") == label and index < len(result):
            return unpack(result[index])
    return None
