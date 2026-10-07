"""Import smoke for the specproc image. One name per line on failure."""
import importlib
import sys

MODS = [
    "specutils",
    "specreduce",
    "pyspeckit",
    "spectres",
    "lmfit",
    "ppxf",
    "pysme",
    "fsps",
    "prospect",
    "sedpy",
    "synple",
    "synspec",
    "turbospectrum",
    "doppler",
    "thecannon",
    "fraunhofer",
    "roland",
    "pyrre",
    "starlyte",
    "moogpy",
    "pymoog",
    "astroARIADNE",
    "atlas_py",
    "synthe_py",
    "agama",
    "vice",
]


def _check_agama() -> str | None:
    try:
        import agama

        agama.Potential(type="Plummer", mass=1.0, scaleRadius=1.0)
    except Exception as exc:
        return f"agama: {exc.__class__.__name__}: {exc}"
    return None


def _check_vice() -> str | None:
    try:
        import vice

        vice.singlezone()
    except Exception as exc:
        return f"vice: {exc.__class__.__name__}: {exc}"
    return None


def _check_innterpol() -> str | None:
    """iNNterpol loads weights from the working directory, not from a package.

    A path-invoked script does not put the working directory on sys.path,
    so the checkout has to be inserted explicitly.
    """
    import os

    root = "/opt/astroai/iNNterpol"
    cwd = os.getcwd()
    sys.path.insert(0, root)
    try:
        os.chdir(root)
        mod = importlib.import_module("innterpol")
        out = mod.innterpol([0.0, 0.0, 0.0, 5500.0, 2.5])
        shape = getattr(out, "shape", None)
        if shape != (71, 4):
            return f"innterpol: unexpected shape {shape}"
    except Exception as exc:
        return f"innterpol: {exc.__class__.__name__}: {exc}"
    finally:
        os.chdir(cwd)
        try:
            sys.path.remove(root)
        except ValueError:
            pass
    return None


def main() -> int:
    bad: list[str] = []
    for name in MODS:
        try:
            importlib.import_module(name)
        except Exception as exc:
            bad.append(f"{name}: {exc.__class__.__name__}: {exc}")
    inn = _check_innterpol()
    if inn:
        bad.append(inn)
    for check in (_check_agama, _check_vice):
        err = check()
        if err:
            bad.append(err)
    if bad:
        print("import failures:", file=sys.stderr)
        print("\n".join(bad), file=sys.stderr)
        return 1
    print("specproc smoke OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
