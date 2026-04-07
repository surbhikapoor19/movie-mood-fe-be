"""
Calls the FastAPI backend.
"""

import os
import requests as http_client
import gradio as gr

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

# ============================================================================
# CONFIGURATION
# ============================================================================
BACKEND_URL = os.environ.get("BACKEND_URL")

# ============================================================================
# CUSTOM CSS
# ============================================================================
custom_css = """
body, .gradio-container {
    background-color:#EDF3F5;
    font-family: 'Arial', sans-serif;
}
.gradio-container {
    max-width: 700px;
    margin: 0 auto;
    padding: 20px;
    border-radius: 15px;
}
h1 {
    font-style: italic;
    font-weight: bold;
    font-size: 40px;
    text-align: center;
    color: #663356;
    text-shadow: 2px 2px 4px #693256;
}
.model-toggle {
    background-color: #f0e6f0;
    border-radius: 10px;
    padding: 10px;
}
"""

# ============================================================================
# UI OPTIONS
# ============================================================================
GENRES           = ["Horror", "Action", "Thriller", "Comedy", "Science-Fiction", "Drama", "Documentary", "Romance", "Animation"]
MOODS            = ["Dark & Intense", "Light & Fun", "Emotional & Deep", "Suspenseful", "Inspirational"]
ERAS             = ["Classic", "90s Classics", "2000s", "2010s", "Recent", "Any Era"]
VIEWING_CONTEXTS = ["Solo", "Family", "Friends", "Any"]
PACE_OPTIONS     = ["Fast-paced", "Slow & character-driven", "Balanced"]


# ============================================================================
# RESPOND FUNCTION
# ============================================================================
def respond(
    message,
    history,
    system_message,
    max_tokens,
    temperature,
    top_p,
    genre,
    mood,
    era,
    viewing_pref,
    pace,
    use_local_model,    # receives value from model_mode_state
):
    payload = {
        "message": message,
        "history": history,
        "genre": genre,
        "mood": mood,
        "era": era,
        "viewing_pref": viewing_pref,
        "pace": pace,
        "system_message": system_message,
        "max_tokens": max_tokens,
        "temperature": temperature,
        "top_p": top_p,
        # Convert the human-readable radio label to a boolean for the backend
        "use_local_model": use_local_model == "Local Model",
    }
    try:
        resp = http_client.post(f"{BACKEND_URL}/chat", json=payload, timeout=300)
        resp.raise_for_status()
        yield resp.json()["response"]
    except Exception as e:
        yield f"Error contacting backend: {e}"


# ============================================================================
# GRADIO UI
# ============================================================================
with gr.Blocks(css=custom_css) as demo:

    # State components for preferences
    g_state          = gr.State(None)
    m_state          = gr.State(None)
    e_state          = gr.State(None)
    v_state          = gr.State(None)
    p_state          = gr.State(None)
    # Holds the currently selected model mode string.
    # Using gr.State (not the widget directly) as the additional_input
    # so respond() always gets a clean string value regardless of
    # Gradio version quirks with Radio inside additional_inputs.
    model_mode_state = gr.State("API Model")

    with gr.Row():
        gr.Markdown("<h1>MOVIE RECOMMENDATION CHATBOT</h1>")

    gr.Markdown("_Movie Recommendation Chatbot_")

    # ── Model selection toggle ────────────────────────────────────────────────
    with gr.Accordion("Model Selection", open=True, elem_classes=["model-toggle"]):
        model_toggle = gr.Radio(
            choices=["API Model", "Local Model"],
            value="API Model",
            label="Choose which model to use for recommendations",
            info="API Model = cloud GPT-OSS 120B  |  Local Model = Qwen 0.5B (runs on server CPU, first request may be slow)",
        )
        model_status = gr.Markdown("Currently using: **API Model**")
    # ─────────────────────────────────────────────────────────────────────────

    with gr.Accordion("Preference Settings", open=True):
        gr.Markdown("*Set your movie preferences to get personalized recommendations*")

        with gr.Row():
            with gr.Column():
                g_radio = gr.Radio(choices=GENRES, label="What is your favourite genre?", interactive=True)
                g_status = gr.Markdown()

                m_radio = gr.Radio(choices=MOODS, label="What mood are you in?", interactive=True)
                m_status = gr.Markdown()

            with gr.Column():
                e_radio = gr.Radio(choices=ERAS, label="Which era of movies do you prefer?", interactive=True)
                e_status = gr.Markdown()

                v_radio = gr.Radio(choices=VIEWING_CONTEXTS, label="What is your viewing context?", interactive=True)
                v_status = gr.Markdown()

            with gr.Column():
                p_radio = gr.Radio(choices=PACE_OPTIONS, label="Do you prefer fast-paced or slower movies?", interactive=True)
                p_status = gr.Markdown()

    gr.Markdown("Set your preferences above, then start chatting to get recommendations!")

    system_tb     = gr.Textbox(value="You are a friendly movie recommendation chatbot.", label="System message", render=False)
    max_tokens_sl = gr.Slider(minimum=1, maximum=2048, value=512, step=1, label="Max new tokens", render=False)
    temp_sl       = gr.Slider(minimum=0.1, maximum=4.0, value=0.3, step=0.1, label="Temperature", render=False)
    top_p_sl      = gr.Slider(minimum=0.1, maximum=1.0, value=0.95, step=0.05, label="Top-p (nucleus sampling)", render=False)

    additional_inputs = [
        system_tb,
        max_tokens_sl,
        temp_sl,
        top_p_sl,
        g_state,
        m_state,
        e_state,
        v_state,
        p_state,
        model_mode_state,   # State object — not the widget — passed to respond()
    ]

    gr.ChatInterface(
        fn=respond,
        additional_inputs=additional_inputs,
        chatbot=gr.Chatbot(render_markdown=True, sanitize_html=False),
    )

    # ── Preference handlers ───────────────────────────────────────────────────
    def set_genre(g):         return g, f"Genre selected: *{g}*"
    def set_mood(m):          return m, f"Mood selected: *{m}*"
    def set_era(e):           return e, f"Era selected: *{e}*"
    def set_viewing_pref(v):  return v, f"Viewing preference selected: *{v}*"
    def set_pace(p):          return p, f"Pace selected: *{p}*"

    g_radio.change(fn=set_genre,        inputs=g_radio, outputs=[g_state, g_status])
    m_radio.change(fn=set_mood,         inputs=m_radio, outputs=[m_state, m_status])
    e_radio.change(fn=set_era,          inputs=e_radio, outputs=[e_state, e_status])
    v_radio.change(fn=set_viewing_pref, inputs=v_radio, outputs=[v_state, v_status])
    p_radio.change(fn=set_pace,         inputs=p_radio, outputs=[p_state, p_status])

    # ── Model toggle handler ──────────────────────────────────────────────────
    # Updates BOTH the state (so respond() gets the new value) AND
    # the status label (so the user sees confirmation of their choice).
    def update_model_status(choice):
        if choice == "Local Model":
            status = "Currently using: **Local Model** — first request may be slow while model loads"
        else:
            status = "Currently using: **API Model**"
        return choice, status   # → [model_mode_state, model_status]

    model_toggle.change(
        fn=update_model_status,
        inputs=model_toggle,
        outputs=[model_mode_state, model_status],
    )

demo.launch()