"""Start the bundled engine in its own process group with writable user caches."""
import os
import runpy


if __name__ == "__main__":
    try:
        os.setsid()
    except PermissionError:
        pass
    runpy.run_module("acestep.acestep_v15_pipeline", run_name="__main__")
