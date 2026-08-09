#!/usr/bin/env python3

import json
import os
import subprocess
import sys
import time

TEMP_DEPENDENCIES = os.path.join(
    os.environ.get("TEMP", r"C:\Users\CYH\AppData\Local\Temp"),
    "overload-g0-selenium",
)
if TEMP_DEPENDENCIES not in sys.path:
    sys.path.insert(0, TEMP_DEPENDENCIES)

from selenium import webdriver
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.support.ui import WebDriverWait


GAME_URL = os.environ.get("G0_GAME_URL", "http://localhost:8080/index.html")
FIREFOX_BINARY = os.environ.get(
    "G0_FIREFOX_BINARY",
    r"C:\Program Files\Mozilla Firefox\firefox.exe",
)
CAPTURE_TIMEOUT_SECONDS = 45


def activate_firefox() -> None:
    command = (
        "$shell=New-Object -ComObject WScript.Shell; "
        "$shell.AppActivate('Mozilla Firefox') | Out-Null"
    )
    subprocess.run(
        ["powershell.exe", "-NoProfile", "-Command", command],
        check=False,
        creationflags=subprocess.CREATE_NO_WINDOW,
    )


def wait_for_game(driver: webdriver.Firefox) -> None:
    WebDriverWait(driver, 60).until(
        lambda current: current.execute_script(
            "return typeof window.__g0InputReady === 'number' && "
            "typeof window.__g0Control === 'function';"
        )
    )
    time.sleep(2)


def environment(driver: webdriver.Firefox) -> dict:
    return driver.execute_script(
        """
        const canvas = document.querySelector('canvas');
        const gl = canvas?.getContext('webgl2') || canvas?.getContext('webgl');
        const extension = gl?.getExtension('WEBGL_debug_renderer_info');
        return {
            browser: navigator.userAgent,
            viewport_css: [window.innerWidth, window.innerHeight],
            screen_css: [screen.width, screen.height],
            device_pixel_ratio: window.devicePixelRatio,
            canvas_pixels: canvas ? [canvas.width, canvas.height] : null,
            webgl_renderer: extension ? gl.getParameter(extension.UNMASKED_RENDERER_WEBGL) : null,
            input_ready_ms: window.__g0InputReady,
        };
        """
    )


def control(driver: webdriver.Firefox, command: str) -> None:
    driver.execute_script("window.__g0Control(arguments[0]);", command)
    time.sleep(0.15)
    state = driver.execute_script(
        "return {"
        "seen: window.__g0ControlSeen || 0, "
        "last: window.__g0LastControl || null, "
        "started: window.__g0CaptureStarted || 0};"
    )
    print(f"G0_CONTROL|{command}|{json.dumps(state, ensure_ascii=False)}", flush=True)


def capture(driver: webdriver.Firefox, label: str) -> dict:
    previous_counter = driver.execute_script("return window.__g0ResultCounter || 0;")
    activate_firefox()
    print(f"G0_CAPTURE_START|{label}", flush=True)
    control(driver, "r")
    deadline = time.time() + CAPTURE_TIMEOUT_SECONDS
    while time.time() < deadline:
        counter = driver.execute_script("return window.__g0ResultCounter || 0;")
        if counter > previous_counter:
            result = driver.execute_script("return window.__g0LastResult;")
            print(
                f"G0_CAPTURE_RESULT|{label}|{json.dumps(result, ensure_ascii=False)}",
                flush=True,
            )
            time.sleep(2)
            return {"label": label, **result}
        time.sleep(0.25)
    raise TimeoutError(f"30-second capture timed out: {label}")


def main() -> None:
    options = Options()
    options.binary_location = FIREFOX_BINARY
    driver = webdriver.Firefox(options=options)
    try:
        driver.set_window_rect(width=1000, height=650)
        driver.get(GAME_URL)
        wait_for_game(driver)
        activate_firefox()
        print(f"G0_ENV|{json.dumps(environment(driver), ensure_ascii=False)}", flush=True)
        results = [capture(driver, "3-4 Firefox A all-on")]
        control(driver, "0")
        results.append(capture(driver, "3-4 Firefox H blank"))
        print(
            f"G0_SUITE_RESULT|firefox|{json.dumps(results, ensure_ascii=False)}",
            flush=True,
        )
    finally:
        driver.quit()


if __name__ == "__main__":
    main()
