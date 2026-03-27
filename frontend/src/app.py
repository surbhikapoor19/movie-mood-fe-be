"""
Calls the FastAPI backend at http://localhost:9010/chat.
"""

import os
import requests as http_client

import gradio as gr

# Load environment variables from .env file for local development
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

# ============================================================================
# CONFIGURATION
# ============================================================================
LOCAL_MODEL = os.environ.get("LOCAL_MODEL", "false").lower() == "true"

BACKEND_URL = os.environ.get("BACKEND_URL", "http://paffenroth-23.dyn.wpi.edu:9010")

# ============================================================================
# CUSTOM CSS  
# ============================================================================
custom_css = """
/* Overall background */
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
"""

# ============================================================================
# UI OPTIONS 
# ============================================================================
GENRES = ["Horror", "Action", "Thriller", "Comedy", "Science-Fiction", "Drama", "Documentary", "Romance", "Animation"]
MOODS = ["Dark & Intense", "Light & Fun", "Emotional & Deep", "Suspenseful", "Inspirational"]
ERAS = ["Classic", "90s Classics", "2000s", "2010s", "Recent", "Any Era"]
VIEWING_CONTEXTS = ["Solo", "Family", "Friends", "Any"]
PACE_OPTIONS = ["Fast-paced", "Slow & character-driven", "Balanced"]


# ============================================================================
# RESPOND FUNCTION
# The original respond() called model functions directly.
# Here it makes one HTTP POST to the backend instead — everything else is identical.
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
    # State components for preferences (must be inside Blocks)
    g_state = gr.State(None)
    m_state = gr.State(None)
    e_state = gr.State(None)
    v_state = gr.State(None)
    p_state = gr.State(None)

    with gr.Row():
        gr.Markdown("<h1>MOVIE RECOMMENDATION CHATBOT</h1>")
    
    gr.Markdown("_Movie Recommendation Chatbot_")

    with gr.Accordion("Preference Settings", open=True):
        gr.Markdown("*Set your movie preferences to get personalized recommendations*")
        
        with gr.Row():
            with gr.Column():
                g_radio = gr.Radio(
                    choices=GENRES,
                    label="What is your favourite genre?",
                    interactive=True
                )
                g_status = gr.Markdown()

                m_radio = gr.Radio(
                    choices=MOODS,
                    label="What mood are you in?",
                    interactive=True
                )
                m_status = gr.Markdown()

            with gr.Column():
                e_radio = gr.Radio(
                    choices=ERAS,
                    label="Which era of movies do you prefer?",
                    interactive=True
                )
                e_status = gr.Markdown()

                v_radio = gr.Radio(
                    choices=VIEWING_CONTEXTS,
                    label="What is your viewing context?",
                    interactive=True
                )
                v_status = gr.Markdown()

            with gr.Column():
                p_radio = gr.Radio(
                    choices=PACE_OPTIONS,
                    label="Do you prefer fast-paced or slower movies?",
                    interactive=True
                )
                p_status = gr.Markdown()

    o_status = gr.Markdown("Set your preferences above, then start chatting to get recommendations!")

    system_tb = gr.Textbox(value="You are a friendly movie recommendation chatbot.", label="System message", render=False)
    max_tokens_sl = gr.Slider(minimum=1, maximum=2048, value=512, step=1, label="Max new tokens", render=False)
    temp_sl = gr.Slider(minimum=0.1, maximum=4.0, value=0.3, step=0.1, label="Temperature", render=False)
    top_p_sl = gr.Slider(minimum=0.1, maximum=1.0, value=0.95, step=0.05, label="Top-p (nucleus sampling)", render=False)

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
    ]

    gr.ChatInterface(
        fn=respond,
        additional_inputs=additional_inputs,
        chatbot=gr.Chatbot(render_markdown=True, sanitize_html=False),
    )

    def set_genre(g):
        return g, f"Genre selected: *{g}*"

    def set_mood(m):
        return m, f"Mood selected: *{m}*"

    def set_era(e):
        return e, f"Era selected: *{e}*"

    def set_viewing_pref(v):
        return v, f"Viewing preference selected: *{v}*"

    def set_pace(p):
        return p, f"Pace selected: *{p}*"

    g_radio.change(fn=set_genre, inputs=g_radio, outputs=[g_state, g_status])
    m_radio.change(fn=set_mood, inputs=m_radio, outputs=[m_state, m_status])
    e_radio.change(fn=set_era, inputs=e_radio, outputs=[e_state, e_status])
    v_radio.change(fn=set_viewing_pref, inputs=v_radio, outputs=[v_state, v_status])
    p_radio.change(fn=set_pace, inputs=p_radio, outputs=[p_state, p_status])


demo.launch()