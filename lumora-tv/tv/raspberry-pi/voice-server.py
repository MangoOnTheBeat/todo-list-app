#!/usr/bin/env python3
"""Lumora offline voice for the Lumora TV box.

Opens the microphone only when Lumora asks ("listen"), recognises speech on the Pi
with Vosk, and sends the words back to Lumora over a WebSocket that only listens on
127.0.0.1. No audio or text leaves the device.

Protocol: Lumora sends "listen"; the server replies with {"partial": "..."} while you
speak and one {"final": "..."} when you stop (empty text if nothing was heard).
"""
import asyncio
import json
import os
import queue

import sounddevice as sd
import websockets
from vosk import KaldiRecognizer, Model, SetLogLevel

MODEL_DIR = os.path.expanduser(os.environ.get("LUMORA_VOSK_MODEL", "~/lumora/vosk-model"))
RATE = 16000
MAX_SECONDS = 8      # never keep the mic open longer than this
QUIET_SECONDS = 1.6  # stop once you've paused this long after speaking

SetLogLevel(-1)
model = Model(MODEL_DIR)


async def listen_once(ws):
    rec = KaldiRecognizer(model, RATE)
    chunks = queue.Queue()
    loop = asyncio.get_running_loop()

    def on_audio(indata, frames, time_info, status):
        chunks.put(bytes(indata))

    def next_chunk():
        try:
            return chunks.get(timeout=0.25)
        except queue.Empty:
            return None

    start = loop.time()
    last_change, last_partial = start, ""
    with sd.RawInputStream(samplerate=RATE, blocksize=4000, dtype="int16", channels=1, callback=on_audio):
        while loop.time() - start < MAX_SECONDS:
            data = await loop.run_in_executor(None, next_chunk)
            if data is None:
                continue
            if rec.AcceptWaveform(data):
                text = json.loads(rec.Result()).get("text", "")
                if text:
                    await ws.send(json.dumps({"final": text}))
                    return
            else:
                partial = json.loads(rec.PartialResult()).get("partial", "")
                if partial != last_partial:
                    last_partial, last_change = partial, loop.time()
                    await ws.send(json.dumps({"partial": partial}))
                elif partial and loop.time() - last_change > QUIET_SECONDS:
                    break
    await ws.send(json.dumps({"final": json.loads(rec.FinalResult()).get("text", "")}))


async def handler(ws):
    async for message in ws:
        if message == "listen":
            try:
                await listen_once(ws)
            except Exception as exc:  # no microphone, device busy, etc.
                await ws.send(json.dumps({"error": str(exc)}))


async def main():
    async with websockets.serve(handler, "127.0.0.1", 8765):
        await asyncio.Future()


if __name__ == "__main__":
    asyncio.run(main())
