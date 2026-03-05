"use client";

import { useState } from "react";

export default function JsonViewer({ data, maxHeight = 300 }) {
    const [expanded, setExpanded] = useState(false);
    const json = typeof data === "string" ? data : JSON.stringify(data, null, 2);

    return (
        <div className="relative">
            <pre
                className="text-xs font-mono bg-slate-950 text-slate-300 rounded-md p-3 overflow-auto border border-slate-800"
                style={{ maxHeight: expanded ? "none" : maxHeight }}
            >
                {json}
            </pre>
            <button
                onClick={() => setExpanded((e) => !e)}
                className="absolute bottom-1 right-1 text-[10px] text-slate-500 hover:text-slate-300 bg-slate-900 border border-slate-700 rounded px-1.5 py-0.5 transition-colors"
            >
                {expanded ? "Collapse" : "Expand"}
            </button>
        </div>
    );
}
