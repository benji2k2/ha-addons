// Nur für Diagnose-Builds (build.yaml: SDK_FRAME_LOG=1). Hängt in das SDK-Bundle eine Debug-Zeile, die jedes
// eingehende P2P-Nicht-Media-Paket nach dem Entschlüsseln mit Befehlsnummer, Name und Inhalt loggt.
//
// Warum hier: Der `[p2p] <<< header=…`-Log des SDK überspringt DATA-Pakete (f1d0) absichtlich. Genau in denen
// kämen Meldungen der Station (z. B. 1201/1164) an. Sie laufen über onData → handleFrame, das loggt nichts.
// Sichtbar nur mit BRIDGE_DEBUG_P2P (Option debug_p2p), weil es über den SDK-Logger auf Stufe debug geht.
import fs from "node:fs";

const file = "/app/node_modules/@mega-yfue/eufy-sdk/dist/index.js";
const anchor = "    const text2 = readNullTerminatedString(data);\n";
const line =
  "    if (!isMedia) this.logger.debug(`[p2p-frame] ${this.cfg.stationSn} cmd=${header.commandId} " +
  "(${commandName(header.commandId)}) type=${dataType} sign=${header.signCode} len=${data.length} " +
  "hex=${Buffer.from(data).subarray(0, 160).toString(\"hex\")} " +
  "text=${JSON.stringify(readNullTerminatedString(data).slice(0, 300))}`);\n";

const src = fs.readFileSync(file, "utf8");
const hits = src.split(anchor).length - 1;
if (hits !== 1) {
  console.error(`sdk-frame-log: Anker ${hits}x gefunden statt 1x, SDK hat sich geändert. Abbruch.`);
  process.exit(1);
}
fs.writeFileSync(file, src.replace(anchor, line + anchor));
console.log("sdk-frame-log: Logzeile in handleFrame eingefügt");
