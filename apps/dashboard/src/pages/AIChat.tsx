import { useState, useRef, useEffect } from "react";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Copy, Sparkles, Send, Trash2, ArrowRight } from "lucide-react";
import { toast } from "sonner";
import { Separator } from "@/components/ui/separator";

// Very simple types for the chat history
type ChatMessage = {
  role: "user" | "model";
  text: string;
  isLoading?: boolean;
};

// Replace with standard env var mechanism for Vite apps
const API_KEY = import.meta.env.VITE_GEMINI_API_KEY || "";
const API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-lite-latest:generateContent";

const SYSTEM_PROMPT = `You are **CaseFlow AI** — an expert Indian legal assistant built into the CaseFlow legal practice management app.
Your expertise covers IPC, CrPC, Evidence Act (and their new Bharatiya Sanhita equivalents), CPC, Constitution, and various local laws.
Keep answers concise, structure with bullet points, and always cite sections/acts. Format currency in ₹. Always add a disclaimer that your advice is for reference only.`;

const SUGGESTIONS = [
  { icon: "⚖️", title: "Section 138 NI Act", query: "Explain Section 138 of Negotiable Instruments Act — cheque bounce procedure, limitation period, and punishment" },
  { icon: "📝", title: "Bail Application", query: "What are the grounds for bail under BNSS? What factors does the court consider?" },
  { icon: "🏛️", title: "Limitation Period", query: "What is the limitation period for filing a civil suit for recovery of money under Limitation Act 1963?" },
  { icon: "📋", title: "FIR Procedure", query: "Explain the procedure for filing FIR under BNSS. What are the rights of the complainant?" },
];

export default function AIChat() {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [input, setInput] = useState("");
  const [isSending, setIsSending] = useState(false);
  const scrollRef = useRef<HTMLDivElement>(null);

  // Auto-scroll to bottom on new message
  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTo({ top: scrollRef.current.scrollHeight, behavior: "smooth" });
    }
  }, [messages, isSending]);

  const handleSend = async (text: string) => {
    if (!text.trim() || isSending) return;

    if (!API_KEY) {
      toast.error("Gemini API key is missing. Add VITE_GEMINI_API_KEY to your .env file.");
      return;
    }

    const userMessage = text.trim();
    setInput("");
    
    // Add optimistic user message + loading state
    setMessages(prev => [
      ...prev,
      { role: "user", text: userMessage },
      { role: "model", text: "", isLoading: true }
    ]);
    setIsSending(true);

    try {
      // Build context payload
      const contents = [
        { role: "user", parts: [{ text: SYSTEM_PROMPT }] },
        { role: "model", parts: [{ text: "Understood. I am CaseFlow AI, ready to assist." }] }
      ];

      // Add actual history
      messages.forEach(msg => {
        if (!msg.isLoading) contents.push({ role: msg.role, parts: [{ text: msg.text }] });
      });

      // Add new message
      contents.push({ role: "user", parts: [{ text: userMessage }] });

      const res = await fetch(`${API_URL}?key=${API_KEY}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents,
          generationConfig: { temperature: 0.7, topK: 40, topP: 0.95, maxOutputTokens: 2048 }
        })
      });

      if (!res.ok) throw new Error("Failed to fetch response from AI");

      const data = await res.json();
      const reply = data.candidates?.[0]?.content?.parts?.[0]?.text || "No response generated.";

      setMessages(prev => {
        const newHistory = [...prev];
        newHistory.pop(); // remove loading message
        newHistory.push({ role: "model", text: reply });
        return newHistory;
      });
    } catch (err) {
      console.error(err);
      toast.error("Failed to connect to the AI model.");
      setMessages(prev => {
        const newHistory = [...prev];
        newHistory.pop();
        newHistory.push({ role: "model", text: "⚠️ Connection error. Please try again later." });
        return newHistory;
      });
    } finally {
      setIsSending(false);
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSend(input);
    }
  };

  const handleCopy = (text: string) => {
    navigator.clipboard.writeText(text);
    toast.success("Message copied to clipboard");
  };

  return (
    <div className="flex flex-col h-[calc(100vh-6rem)] relative overflow-hidden bg-background rounded-xl border border-border shadow-sm">
      {/* Header */}
      <div className="flex items-center justify-between px-6 py-4 border-b border-border bg-card/50 backdrop-blur-sm z-10">
        <div className="flex items-center gap-3">
          <div className="h-10 w-10 rounded-xl bg-gradient-to-br from-indigo-500 to-cyan-400 flex items-center justify-center shadow-inner">
            <Sparkles className="w-5 h-5 text-white" />
          </div>
          <div>
            <h2 className="text-lg font-bold">CaseFlow AI</h2>
            <div className="flex items-center gap-2 text-xs font-medium text-muted-foreground">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
              Powered by Gemini
            </div>
          </div>
        </div>
        
        {messages.length > 0 && (
          <Button variant="ghost" size="sm" onClick={() => setMessages([])} className="text-muted-foreground hover:text-destructive transition-colors">
            <Trash2 className="w-4 h-4 mr-2" /> Clear Chat
          </Button>
        )}
      </div>

      {/* Chat Area */}
      <div className="flex-1 overflow-y-auto p-6" ref={scrollRef}>
        {messages.length === 0 ? (
          <div className="h-full flex flex-col items-center justify-center animate-fade-in text-center max-w-2xl mx-auto space-y-8">
            <div className="w-20 h-20 rounded-3xl bg-gradient-to-br from-indigo-500 via-cyan-400 to-emerald-400 flex items-center justify-center shadow-[0_8px_30px_rgb(99,102,241,0.3)]">
              <Sparkles className="w-10 h-10 text-white" />
            </div>
            
            <div className="space-y-2">
              <h1 className="text-3xl font-extrabold tracking-tight">How can I assist you today?</h1>
              <p className="text-muted-foreground text-lg">Your expert AI assistant for Indian legal research, drafting, and analysis.</p>
            </div>

            <Separator className="w-1/2" />

            <div className="w-full text-left space-y-4">
              <p className="text-sm font-semibold tracking-widest text-muted-foreground uppercase">Try asking about</p>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                {SUGGESTIONS.map((s, i) => (
                  <div 
                    key={i}
                    onClick={() => handleSend(s.query)}
                    className="p-4 rounded-xl border border-border/50 bg-card hover:bg-accent/50 hover:border-primary/20 cursor-pointer transition-all duration-200 group flex items-start gap-4"
                  >
                    <span className="text-2xl mt-0.5">{s.icon}</span>
                    <div className="flex-1 space-y-1">
                      <p className="font-semibold text-sm group-hover:text-primary transition-colors">{s.title}</p>
                      <p className="text-xs text-muted-foreground line-clamp-1">{s.query}</p>
                    </div>
                    <ArrowRight className="w-4 h-4 text-muted-foreground opacity-0 group-hover:opacity-100 transition-all self-center transform group-hover:translate-x-1" />
                  </div>
                ))}
              </div>
            </div>
          </div>
        ) : (
          <div className="space-y-6 max-w-4xl mx-auto pb-6">
            {messages.map((msg, idx) => (
              <div key={idx} className={`flex gap-4 ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}>
                {msg.role === 'model' && (
                  <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-indigo-500 to-cyan-400 flex-shrink-0 flex items-center justify-center mt-1 outline outline-1 outline-indigo-500/20">
                    <Sparkles className="w-4 h-4 text-white" />
                  </div>
                )}
                
                <div className={`group relative max-w-[85%] rounded-2xl px-5 py-4 ${
                  msg.role === 'user' 
                    ? 'bg-primary text-primary-foreground rounded-tr-sm shadow-md' 
                    : 'bg-card border border-border/60 shadow-sm rounded-tl-sm'
                }`}>
                  {msg.isLoading ? (
                    <div className="flex items-center gap-2 h-6">
                      <div className="flex gap-1">
                        <span className="w-2 h-2 bg-indigo-400 rounded-full animate-bounce [animation-delay:-0.3s]"></span>
                        <span className="w-2 h-2 bg-indigo-400 rounded-full animate-bounce [animation-delay:-0.15s]"></span>
                        <span className="w-2 h-2 bg-indigo-400 rounded-full animate-bounce"></span>
                      </div>
                      <span className="text-sm italic text-muted-foreground ml-2">Analyzing laws...</span>
                    </div>
                  ) : (
                    <div className="prose prose-sm dark:prose-invert max-w-none prose-p:leading-relaxed">
                      {/* Simple render of text; for fully featured, use a markdown renderer here */}
                      <div className="whitespace-pre-wrap">{msg.text}</div>
                    </div>
                  )}

                  {/* Actions for model messages */}
                  {msg.role === 'model' && !msg.isLoading && (
                    <div className="absolute -bottom-3 left-4 opacity-0 group-hover:opacity-100 transition-opacity bg-background border border-border rounded-md shadow-sm flex items-center p-1">
                      <Button variant="ghost" size="icon" className="h-6 w-6 text-muted-foreground hover:text-foreground" onClick={() => handleCopy(msg.text)}>
                        <Copy className="w-3 h-3" />
                      </Button>
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Input Area */}
      <div className="p-4 bg-card border-t border-border z-10">
        <div className="max-w-4xl mx-auto relative rounded-2xl bg-background border border-input shadow-sm focus-within:ring-1 focus-within:ring-primary/50 focus-within:border-primary transition-all">
          <Textarea 
            value={input}
            onChange={e => setInput(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="Ask about any legal scenario, procedures, or drafting..."
            className="min-h-[60px] max-h-48 resize-none border-0 bg-transparent focus-visible:ring-0 px-5 py-4 text-base scrollbar-hide"
            disabled={isSending}
          />
          <div className="absolute right-3 bottom-3 flex items-center">
            <Button 
              size="icon" 
              className={`h-10 w-10 rounded-full shadow-sm ${input.trim() ? 'bg-primary' : 'bg-muted text-muted-foreground'}`}
              disabled={!input.trim() || isSending}
              onClick={() => handleSend(input)}
            >
              <Send className="w-4 h-4 ml-0.5" />
            </Button>
          </div>
        </div>
        <p className="text-center text-[10px] text-muted-foreground font-medium mt-3 uppercase tracking-wider">
          AI generated content is for reference only and does not substitute professional legal counsel.
        </p>
      </div>
    </div>
  );
}
