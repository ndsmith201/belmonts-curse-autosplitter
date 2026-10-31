#!/usr/bin/env python3
"""Compile and exercise the real ASL actions without LiveSplit or game memory.

Requires a .NET 8 SDK. Use --dotnet /path/to/dotnet or set DOTNET.
Build output stays in a temporary directory; no NuGet packages are required.
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "BelmontsCurse-Bosses.asl"
CHECKS = ["fallen", "joan", "medusa", "death_1", "isaac_1", "talos",
          "carmilla", "death_2", "isaac_2", "dracula"]
CHECK_NAMES = {"fallen": "The Fallen", "joan": "Joan", "medusa": "Medusa",
               "death_1": "Death 1", "isaac_1": "Isaac 1", "talos": "Talos",
               "carmilla": "Carmilla", "death_2": "Death 2", "isaac_2": "Isaac 2",
               "dracula": "Dracula"}


def extract_actions(source: str) -> str:
    actions = []
    # ASL's outer action braces are at column zero; nested C# is indented.
    pattern = re.compile(r"^([a-zA-Z][a-zA-Z0-9_]*)\n\{\n(.*?)^\}", re.M | re.S)
    for match in pattern.finditer(source):
        name, body = match.groups()
        line = source.count("\n", 0, match.start(2)) + 1
        # This is the same bare-return rewrite and trailing null used by ASLMethod.
        body = body.replace("return;", "return null;")
        actions.append(f"public dynamic {name}() {{\n#line {line} \"{SCRIPT.as_posix()}\"\n"
                       f"{body}\n#line default\nreturn null;\n}}\n")
    found = {m.group(1) for m in pattern.finditer(source)}
    required = {"startup", "init", "update", "isLoading", "start", "split",
                "onSplit", "onStart", "onReset", "exit", "shutdown"}
    assert found == required, f"Update action extraction for: {found ^ required}"
    return "\n".join(actions)


def extract_component_reader(source: str) -> str:
    """Install the actual native component subreader for cache regression tests."""
    start = source.index("    vars.draculaComponents =")
    end = source.index("    vars.draculaStatValue =", start)
    line = source.count("\n", 0, start) + 1
    body = source[start:end].replace("return;", "return null;")
    return (f"public void InstallDraculaComponents() {{\n#line {line} \"{SCRIPT.as_posix()}\"\n"
            f"{body}\n#line default\n}}\n")


def check_fixtures() -> None:
    for order in ("Talos-First", "Carmilla-First"):
        path = ROOT / f"BelmontsCurse-Bosses-{order}.lss"
        root = ET.parse(path).getroot()
        labels = [node.findtext("Name", "") for node in root.findall("./Segments/Segment")]
        expected = CHECKS.copy()
        if order == "Carmilla-First":
            expected[5:7] = ["carmilla", "talos"]
        expected_labels = [CHECK_NAMES[key] for key in expected]
        assert labels == expected_labels, f"{path.name}: labels {labels} != {expected_labels}"
        assert root.find("./Metadata/CustomVariables/Variable") is None, \
            f"{path.name}: remove the obsolete fixed-route marker"
    print("PASS: both .lss fixtures contain clean names in their advertised boss order", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dotnet", default=os.environ.get("DOTNET") or shutil.which("dotnet"))
    args = parser.parse_args()
    if not args.dotnet:
        parser.error(".NET SDK not found; supply --dotnet /path/to/dotnet or set DOTNET")

    source = SCRIPT.read_text()
    template = (ROOT / "tests" / "RouteTests.cs").read_text()
    assert template.count("// INSERT_ACTUAL_ASL_ACTIONS") == 1
    generated = template.replace("// INSERT_ACTUAL_ASL_ACTIONS", extract_actions(source))
    assert generated.count("// INSERT_ACTUAL_COMPONENT_READER") == 1
    generated = generated.replace("// INSERT_ACTUAL_COMPONENT_READER", extract_component_reader(source))
    with tempfile.TemporaryDirectory(prefix="belmont-asl-tests-") as directory:
        build = Path(directory)
        (build / "Program.cs").write_text(generated)
        (build / "RouteTests.csproj").write_text("""<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType><TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>disable</ImplicitUsings><Nullable>disable</Nullable>
    <NoWarn>CS0162</NoWarn><RestoreIgnoreFailedSources>true</RestoreIgnoreFailedSources>
  </PropertyGroup>
</Project>
""")
        (build / "NuGet.Config").write_text("<configuration><packageSources><clear /></packageSources></configuration>")
        env = os.environ.copy()
        env.update(DOTNET_CLI_TELEMETRY_OPTOUT="1", DOTNET_SKIP_FIRST_TIME_EXPERIENCE="1",
                   DOTNET_GENERATE_ASPNET_CERTIFICATE="false", DOTNET_NOLOGO="1",
                   DOTNET_CLI_WORKLOAD_UPDATE_NOTIFY_DISABLE="true", DOTNET_CLI_DO_NOT_USE_MSBUILD_SERVER="1",
                   DOTNET_CLI_HOME=str(build / "cli"))
        subprocess.run([args.dotnet, "run", "--project", str(build / "RouteTests.csproj"),
                        "--configuration", "Release", "--nologo", "-p:UseSharedCompilation=false"],
                       check=True, env=env, cwd=build)
    check_fixtures()


if __name__ == "__main__":
    main()
