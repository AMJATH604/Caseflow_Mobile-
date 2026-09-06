import React from "react";

interface Props { children: React.ReactNode; }
interface State { hasError: boolean; error: Error | null; errorInfo: React.ErrorInfo | null; }

export class ErrorBoundary extends React.Component<Props, State> {
    constructor(props: Props) {
        super(props);
        this.state = { hasError: false, error: null, errorInfo: null };
    }

    static getDerivedStateFromError(error: Error) {
        return { hasError: true, error };
    }

    componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
        this.setState({ errorInfo });
        console.error("ErrorBoundary caught:", error, errorInfo);
    }

    render() {
        if (this.state.hasError) {
            return (
                <div style={{ padding: 24, fontFamily: "monospace", fontSize: 13, background: "#1a1a2e", color: "#e94560", minHeight: "100vh" }}>
                    <h2 style={{ color: "#fff", marginBottom: 16 }}>⚠️ App Crashed</h2>
                    <div style={{ background: "#16213e", padding: 16, borderRadius: 8, marginBottom: 12, wordBreak: "break-word" }}>
                        <strong style={{ color: "#e94560" }}>{this.state.error?.name}:</strong>{" "}
                        <span style={{ color: "#fff" }}>{this.state.error?.message}</span>
                    </div>
                    <pre style={{ background: "#16213e", padding: 16, borderRadius: 8, overflow: "auto", color: "#a5a5c0", fontSize: 11, whiteSpace: "pre-wrap" }}>
                        {this.state.error?.stack}
                    </pre>
                    <button
                        onClick={() => { this.setState({ hasError: false, error: null, errorInfo: null }); window.location.reload(); }}
                        style={{ marginTop: 16, padding: "10px 20px", background: "#e94560", color: "#fff", border: "none", borderRadius: 8, fontWeight: "bold", cursor: "pointer" }}
                    >
                        Reload App
                    </button>
                </div>
            );
        }
        return this.props.children;
    }
}
