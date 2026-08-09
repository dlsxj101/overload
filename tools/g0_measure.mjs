#!/usr/bin/env node

import { writeFile } from "node:fs/promises";

const CDP_ENDPOINT = process.env.G0_CDP_ENDPOINT ?? "http://127.0.0.1:9222";
const TARGET_URL_FRAGMENT = process.env.G0_TARGET_URL ?? "localhost:8080";
const READY_TIMEOUT_MS = 60_000;
const CAPTURE_TIMEOUT_MS = 45_000;
const SETTLE_MS = 2_000;

const sleep = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

class CdpClient {
	constructor(webSocketUrl) {
		this.webSocketUrl = webSocketUrl;
		this.socket = null;
		this.nextId = 1;
		this.pending = new Map();
		this.listeners = new Map();
	}

	async connect() {
		this.socket = new WebSocket(this.webSocketUrl);
		this.socket.onmessage = (event) => {
			const message = JSON.parse(event.data);
			if (!message.id) {
				for (const listener of this.listeners.get(message.method) ?? []) {
					listener(message.params ?? {});
				}
				return;
			}
			if (!this.pending.has(message.id)) return;
			const { resolve, reject } = this.pending.get(message.id);
			this.pending.delete(message.id);
			if (message.error) reject(new Error(JSON.stringify(message.error)));
			else resolve(message.result);
		};
		await new Promise((resolve, reject) => {
			this.socket.onopen = resolve;
			this.socket.onerror = reject;
		});
	}

	on(method, listener) {
		if (!this.listeners.has(method)) this.listeners.set(method, []);
		this.listeners.get(method).push(listener);
	}

	send(method, params = {}) {
		const id = this.nextId++;
		return new Promise((resolve, reject) => {
			this.pending.set(id, { resolve, reject });
			this.socket.send(JSON.stringify({ id, method, params }));
		});
	}

	close() {
		this.socket?.close();
	}
}

async function findGameTarget() {
	const response = await fetch(`${CDP_ENDPOINT}/json/list`);
	if (!response.ok) throw new Error(`CDP target query failed: ${response.status}`);
	const targets = await response.json();
	const target = targets.find((candidate) =>
		candidate.type === "page" && candidate.url.includes(TARGET_URL_FRAGMENT)
	);
	if (!target) throw new Error(`No page target containing ${TARGET_URL_FRAGMENT}`);
	return target;
}

async function evaluate(client, expression) {
	const response = await client.send("Runtime.evaluate", {
		expression,
		returnByValue: true,
		awaitPromise: true,
	});
	if (response.exceptionDetails) {
		throw new Error(response.exceptionDetails.text ?? "Runtime.evaluate failed");
	}
	return response.result.value;
}

async function waitUntil(check, timeoutMilliseconds, description) {
	const started = Date.now();
	while (Date.now() - started < timeoutMilliseconds) {
		if (await check()) return;
		await sleep(250);
	}
	throw new Error(`Timed out: ${description}`);
}

async function waitForGame(client) {
	await waitUntil(
		async () => await evaluate(client, "typeof window.__g0InputReady === 'number'"),
		READY_TIMEOUT_MS,
		"Godot G0 input readiness",
	);
	await evaluate(client, "document.querySelector('canvas')?.focus()")
}

async function reload(client) {
	await client.send("Page.reload", { ignoreCache: true });
	await waitForGame(client);
	await sleep(SETTLE_MS);
}

function keyParameters(key, type) {
	const upper = key.toUpperCase();
	const isDigit = /^[0-9]$/.test(key);
	const windowsVirtualKeyCode = isDigit ? key.charCodeAt(0) : upper.charCodeAt(0);
	return {
		type,
		key: isDigit ? key : key.toLowerCase(),
		code: isDigit ? `Digit${key}` : `Key${upper}`,
		windowsVirtualKeyCode,
		nativeVirtualKeyCode: windowsVirtualKeyCode,
		text: type === "keyDown" ? key.toLowerCase() : undefined,
		unmodifiedText: type === "keyDown" ? key.toLowerCase() : undefined,
	};
}

async function pressKey(client, key) {
	const hasControlBridge = await evaluate(client, "typeof window.__g0Control === 'function'");
	if (hasControlBridge) {
		await evaluate(client, `window.__g0Control(${JSON.stringify(key)})`);
		await sleep(150);
		const controlState = await evaluate(client, "({seen: window.__g0ControlSeen || 0, last: window.__g0LastControl || null, started: window.__g0CaptureStarted || 0})");
		console.log(`G0_CONTROL|${key}|${JSON.stringify(controlState)}`);
		return;
	}
	await evaluate(client, "document.querySelector('canvas')?.focus()");
	await client.send("Input.dispatchKeyEvent", keyParameters(key, "keyDown"));
	await client.send("Input.dispatchKeyEvent", keyParameters(key, "keyUp"));
	await sleep(150);
}

async function capture(client, label) {
	const previousCounter = await evaluate(client, "window.__g0ResultCounter || 0");
	console.log(`G0_CAPTURE_START|${label}`);
	await pressKey(client, "r");
	await waitUntil(
		async () => (await evaluate(client, "window.__g0ResultCounter || 0")) > previousCounter,
		CAPTURE_TIMEOUT_MS,
		`30-second capture ${label}`,
	);
	const result = await evaluate(client, "window.__g0LastResult");
	console.log(`G0_CAPTURE_RESULT|${label}|${JSON.stringify(result)}`);
	await sleep(SETTLE_MS);
	return { label, ...result };
}

async function environment(client) {
	const browserVersion = await fetch(`${CDP_ENDPOINT}/json/version`).then((response) => response.json());
	const pageEnvironment = await evaluate(client, `(() => {
		const canvas = document.querySelector('canvas');
		const gl = canvas?.getContext('webgl2') || canvas?.getContext('webgl');
		const extension = gl?.getExtension('WEBGL_debug_renderer_info');
		return {
			user_agent: navigator.userAgent,
			viewport_css: [window.innerWidth, window.innerHeight],
			screen_css: [screen.width, screen.height],
			device_pixel_ratio: window.devicePixelRatio,
			canvas_pixels: canvas ? [canvas.width, canvas.height] : null,
			webgl_renderer: extension ? gl.getParameter(extension.UNMASKED_RENDERER_WEBGL) : null,
			input_ready_ms: window.__g0InputReady,
		};
	})()`);
	return {
		browser: browserVersion.Browser,
		protocol: browserVersion["Protocol-Version"],
		...pageEnvironment,
	};
}

async function runOriginIsolation(client) {
	await reload(client);
	const results = [];
	results.push(await capture(client, "3-1 A all-on"));
	await pressKey(client, "1");
	results.push(await capture(client, "3-1 B player-redraw-off"));
	await pressKey(client, "2");
	results.push(await capture(client, "3-1 C enemy-render-off"));
	await pressKey(client, "4");
	results.push(await capture(client, "3-1 D f1-tree-freed"));
	await pressKey(client, "3");
	results.push(await capture(client, "3-1 E saturation-freed"));
	await pressKey(client, "5");
	results.push(await capture(client, "3-1 F shake-off"));
	await pressKey(client, "6");
	results.push(await capture(client, "3-1 G combo-layer-off"));
	await pressKey(client, "0");
	results.push(await capture(client, "3-1 H blank"));
	return results;
}

async function runEnemyScale(client) {
	await reload(client);
	for (const key of ["1", "3", "4", "5", "6", "7"]) await pressKey(client, key);
	const results = [await capture(client, "3-2 enemies-1")];
	for (const count of [10, 50, 100, 150]) {
		await pressKey(client, "n");
		results.push(await capture(client, `3-2 enemies-${count}`));
	}
	return results;
}

async function runTierComparison(client) {
	await reload(client);
	await pressKey(client, "n");
	const results = [await capture(client, "3-3 tier-0 saturation-on")];
	await pressKey(client, "3");
	results.push(await capture(client, "3-3 tier-0 saturation-off"));
	await pressKey(client, "3");
	await pressKey(client, "t");
	results.push(await capture(client, "3-3 tier-4 saturation-on"));
	await pressKey(client, "3");
	results.push(await capture(client, "3-3 tier-4 saturation-off"));
	return results;
}

async function runBrowserBaseline(client) {
	await reload(client);
	const results = [await capture(client, "3-4 A all-on")];
	await pressKey(client, "0");
	results.push(await capture(client, "3-4 H blank"));
	return results;
}

async function runControlCheck(client) {
	await reload(client);
	await pressKey(client, "r");
	await sleep(1_000);
	const state = await evaluate(client, "({counter: window.__g0ResultCounter || 0, started: window.__g0CaptureStarted || 0, seen: window.__g0ControlSeen || 0})");
	await pressKey(client, "r");
	return [state];
}

async function runVisualCheck(client) {
	await reload(client);
	await pressKey(client, "f2");
	await sleep(1_000);
	const screenshot = await client.send("Page.captureScreenshot", {
		format: "png",
		fromSurface: true,
	});
	const outputPath = process.env.G0_SCREENSHOT_PATH
		?? "C:/Users/CYH/AppData/Local/Temp/overload-g0-profile.png";
	await writeFile(outputPath, Buffer.from(screenshot.data, "base64"));
	console.log(`G0_SCREENSHOT|${outputPath}`);
	return [{ outputPath }];
}

async function runAnimationFrameHistory(client) {
	await waitUntil(
		async () => await evaluate(client, "document.querySelector('canvas') !== null"),
		READY_TIMEOUT_MS,
		"Godot canvas",
	);
	await sleep(2_000);
	if (process.env.G0_RAF_OPEN_F1 === "1") {
		await client.send("Input.dispatchKeyEvent", {
			type: "rawKeyDown",
			key: "F1",
			code: "F1",
			windowsVirtualKeyCode: 112,
			nativeVirtualKeyCode: 112,
		});
		await client.send("Input.dispatchKeyEvent", {
			type: "keyUp",
			key: "F1",
			code: "F1",
			windowsVirtualKeyCode: 112,
			nativeVirtualKeyCode: 112,
		});
		await sleep(2_000);
	}
	console.log("G0_CAPTURE_START|historical requestAnimationFrame");
	const result = await evaluate(client, `new Promise((resolve) => {
		const durationMs = 30000;
		const samples = [];
		let startedAt = null;
		let previousAt = null;
		function frame(now) {
			if (startedAt === null) {
				startedAt = now;
				previousAt = now;
			} else {
				samples.push(now - previousAt);
				previousAt = now;
			}
			if (now - startedAt < durationMs) {
				requestAnimationFrame(frame);
				return;
			}
			const sorted = [...samples].sort((a, b) => a - b);
			const total = samples.reduce((sum, value) => sum + value, 0);
			const p99Index = Math.max(0, Math.ceil(sorted.length * 0.99) - 1);
			const slowCount = Math.max(1, Math.ceil(sorted.length * 0.01));
			const slowAverage = sorted.slice(-slowCount).reduce((sum, value) => sum + value, 0) / slowCount;
			resolve({
				duration_seconds: (previousAt - startedAt) / 1000,
				sample_count: samples.length,
				frame_average_ms: total / samples.length,
				frame_max_ms: sorted[sorted.length - 1],
				frame_p99_ms: sorted[p99Index],
				one_percent_low_fps: 1000 / slowAverage,
			});
		}
		requestAnimationFrame(frame);
	})`);
	console.log(`G0_CAPTURE_RESULT|historical requestAnimationFrame|${JSON.stringify(result)}`);
	return [result];
}

async function runNetworkMeasurement(client) {
	const productionUrl = process.env.G0_PRODUCTION_URL;
	if (!productionUrl) throw new Error("G0_PRODUCTION_URL is required for network mode");
	const productionOrigin = new URL(productionUrl).origin;
	const responses = new Map();
	client.on("Network.responseReceived", ({ requestId, response, type }) => {
		if (!response.url.startsWith(productionOrigin)) return;
		responses.set(requestId, {
			requestId,
			url: response.url,
			status: response.status,
			mimeType: response.mimeType,
			type,
			headers: response.headers,
			fromDiskCache: response.fromDiskCache,
			fromServiceWorker: response.fromServiceWorker,
		});
	});
	client.on("Network.loadingFinished", ({ requestId, encodedDataLength }) => {
		if (!responses.has(requestId)) return;
		responses.get(requestId).encodedDataLength = encodedDataLength;
		responses.get(requestId).finished = true;
	});

	await client.send("Network.enable", {
		maxTotalBufferSize: 100_000_000,
		maxResourceBufferSize: 60_000_000,
	});
	await client.send("Network.setCacheDisabled", { cacheDisabled: true });
	await client.send("Network.clearBrowserCache");
	const navigationStartedAt = Date.now();
	await client.send("Page.navigate", { url: productionUrl });
	await waitUntil(
		async () => await evaluate(client, "typeof window.__g0InputReady === 'number'"),
		READY_TIMEOUT_MS,
		"public Godot input readiness",
	);
	await sleep(1_000);

	const timing = await evaluate(client, `(() => {
		const navigation = performance.getEntriesByType('navigation')[0];
		const canvas = document.querySelector('canvas');
		const gl = canvas?.getContext('webgl2') || canvas?.getContext('webgl');
		const extension = gl?.getExtension('WEBGL_debug_renderer_info');
		return {
			url: location.href,
			input_ready_ms: window.__g0InputReady,
			load_event_end_ms: navigation?.loadEventEnd ?? 0,
			dom_complete_ms: navigation?.domComplete ?? 0,
			response_end_ms: navigation?.responseEnd ?? 0,
			redirect_count: navigation?.redirectCount ?? 0,
			wall_clock_to_ready_ms: Date.now() - ${navigationStartedAt},
			user_agent: navigator.userAgent,
			screen_css: [screen.width, screen.height],
			viewport_css: [innerWidth, innerHeight],
			device_pixel_ratio: devicePixelRatio,
			webgl_renderer: extension ? gl.getParameter(extension.UNMASKED_RENDERER_WEBGL) : null,
		};
	})()`);

	const resourceRows = [];
	for (const response of responses.values()) {
		let decodedBodyBytes = null;
		if (/\/game\/index\.(wasm|pck|js)$/.test(new URL(response.url).pathname)) {
			try {
				const body = await client.send("Network.getResponseBody", { requestId: response.requestId });
				decodedBodyBytes = body.base64Encoded
					? Buffer.from(body.body, "base64").byteLength
					: Buffer.byteLength(body.body);
			} catch {
				decodedBodyBytes = null;
			}
		}
		const normalizedHeaders = Object.fromEntries(
			Object.entries(response.headers ?? {}).map(([key, value]) => [key.toLowerCase(), value]),
		);
		resourceRows.push({
			url: response.url,
			status: response.status,
			type: response.type,
			mime_type: response.mimeType,
			content_encoding: normalizedHeaders["content-encoding"] ?? null,
			content_length_header: normalizedHeaders["content-length"] ?? null,
			encoded_data_length: response.encodedDataLength ?? 0,
			decoded_body_bytes: decodedBodyBytes,
			from_disk_cache: response.fromDiskCache,
			from_service_worker: response.fromServiceWorker,
		});
	}
	resourceRows.sort((left, right) => left.url.localeCompare(right.url));
	const totalEncodedBytes = resourceRows.reduce(
		(total, row) => total + row.encoded_data_length,
		0,
	);
	const result = { timing, total_encoded_bytes: totalEncodedBytes, resources: resourceRows };
	console.log(`G0_NETWORK_RESULT|${JSON.stringify(result)}`);
	return [result];
}

async function main() {
	const suite = process.argv[2] ?? "browser";
	const target = await findGameTarget();
	const client = new CdpClient(target.webSocketDebuggerUrl);
	await client.connect();
	try {
		await client.send("Page.enable");
		await client.send("Runtime.enable");
		await client.send("Page.bringToFront");
		if (suite !== "raf" && suite !== "network") await waitForGame(client);
		console.log(`G0_ENV|${JSON.stringify(await environment(client))}`);
		let results;
		switch (suite) {
			case "origin": results = await runOriginIsolation(client); break;
			case "scale": results = await runEnemyScale(client); break;
			case "tiers": results = await runTierComparison(client); break;
			case "browser": results = await runBrowserBaseline(client); break;
			case "control": results = await runControlCheck(client); break;
			case "visual": results = await runVisualCheck(client); break;
			case "raf": results = await runAnimationFrameHistory(client); break;
			case "network": results = await runNetworkMeasurement(client); break;
			default: throw new Error(`Unknown suite: ${suite}`);
		}
		console.log(`G0_SUITE_RESULT|${suite}|${JSON.stringify(results)}`);
	} finally {
		client.close();
	}
}

main().catch((error) => {
	console.error(error.stack ?? String(error));
	process.exitCode = 1;
});
