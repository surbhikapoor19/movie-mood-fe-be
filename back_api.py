"""
back_api.py  —  FastAPI backend (API-based product), port 9010
Uses HuggingFace Inference API for LLM inference — no local model dependencies.
"""

import json
import re
import os
import requests

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

# ============================================================================
# CONFIGURATION
# ============================================================================
API_MODEL_NAME = "openai/gpt-oss-120b"

# ============================================================================
# TMDB API CONFIGURATION
# ============================================================================
TMDB_BASE_URL = "https://api.themoviedb.org/3"
TMDB_IMAGE_BASE_URL = "https://image.tmdb.org/t/p/w300"


def get_tmdb_api_key():
    """Get TMDB API key from environment variable."""
    return os.environ.get("TMDB_API_KEY", "")


def search_movie_tmdb(title: str, year: int = None) -> dict | None:
    """Search for a movie on TMDB by title and optionally year."""
    api_key = get_tmdb_api_key()
    if not api_key:
        print(f"[INFO] TMDB: No API key configured, skipping lookup for '{title}'")
        return None

    params = {
        "api_key": api_key,
        "query": title,
        "include_adult": False,
    }
    if year:
        params["year"] = year

    try:
        print(f"[INFO] TMDB: Searching for '{title}' ({year or 'any year'})...")
        response = requests.get(f"{TMDB_BASE_URL}/search/movie", params=params, timeout=10)
        response.raise_for_status()
        data = response.json()
        results = data.get("results", [])

        if results:
            found = results[0]
            print(f"[INFO] TMDB: Found '{found.get('title')}' (rating: {found.get('vote_average', 'N/A')})")
            return found
        print(f"[INFO] TMDB: No results found for '{title}'")
        return None
    except requests.RequestException as e:
        print(f"[WARN] TMDB: Request failed for '{title}': {e}")
        return None


def get_movie_details_tmdb(movie_id: int) -> dict | None:
    """Get detailed movie information from TMDB."""
    api_key = get_tmdb_api_key()
    if not api_key:
        return None

    try:
        response = requests.get(
            f"{TMDB_BASE_URL}/movie/{movie_id}",
            params={"api_key": api_key},
            timeout=10
        )
        response.raise_for_status()
        return response.json()
    except requests.RequestException:
        return None


def format_movie_card_with_tmdb(title: str, year: int, why: str, index: int) -> str:
    """Format a movie card, enriching with TMDB data if available."""
    tmdb_data = search_movie_tmdb(title, year)

    if tmdb_data:
        tmdb_title = tmdb_data.get("title", title)
        tmdb_year = tmdb_data.get("release_date", "")[:4] if tmdb_data.get("release_date") else str(year)
        rating = tmdb_data.get("vote_average", 0)
        overview = tmdb_data.get("overview", "")
        poster_path = tmdb_data.get("poster_path")

        if len(overview) > 200:
            overview = overview[:200] + "..."

        if poster_path:
            poster_html = f'<img src="{TMDB_IMAGE_BASE_URL}{poster_path}" alt="{tmdb_title}" style="max-width: 150px; border-radius: 8px; margin-right: 15px;">'
        else:
            poster_html = '<div style="width: 150px; min-width: 150px; height: 225px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 8px; margin-right: 15px; display: flex; align-items: center; justify-content: center; color: white; font-size: 48px;">🎬</div>'

        return f"""
                <div style="display: flex; margin-bottom: 20px; padding: 15px; background: #f8f9fa; border-radius: 10px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
                    {poster_html}
                    <div style="flex: 1;">
                        <h3 style="margin: 0 0 5px 0; color: #333;">{index}. {tmdb_title} ({tmdb_year})</h3>
                        <p style="margin: 5px 0;"><strong>Rating:</strong> {rating:.1f}/10</p>
                        <p style="margin: 5px 0;"><em>{why}</em></p>
                        <p style="margin: 5px 0; color: #666; font-size: 0.9em;">{overview}</p>
                    </div>
                </div>
                """
    else:
        placeholder_html = '<div style="width: 150px; min-width: 150px; height: 225px; background: linear-gradient(135deg, #a8a8a8 0%, #6b6b6b 100%); border-radius: 8px; margin-right: 15px; display: flex; align-items: center; justify-content: center; color: white; font-size: 48px;">🎬</div>'
        year_display = f" ({year})" if year else ""

        return f"""
                <div style="display: flex; margin-bottom: 20px; padding: 15px; background: #f8f9fa; border-radius: 10px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
                {placeholder_html}
                    <div style="flex: 1;">
                        <h3 style="margin: 0 0 5px 0; color: #333;">{index}. {title}{year_display}</h3>
                        <p style="margin: 5px 0; color: #888;"><em>Movie details not available from TMDB</em></p>
                        <p style="margin: 5px 0;"><em>{why}</em></p>
                    </div>
                </div>
                """


# ============================================================================
# MODEL INITIALIZATION
# ============================================================================
print("[MODE] API-based backend — using HuggingFace Inference API")
from huggingface_hub import InferenceClient

# ============================================================================
# PROMPT ENGINEERING
# ============================================================================
SYSTEM_PROMPT = """You are a movie recommender. Recommend 3-5 movies matching the user's preferences.

CRITICAL: Output ONLY valid JSON. No text before or after. Follow this EXACT format:

{"user_mentioned_movies":["Movie1"],"recommendations":[{"title":"Movie A","year":2020,"why":"Reason 1"},{"title":"Movie B","year":2019,"why":"Reason 2"},{"title":"Movie C","year":2018,"why":"Reason 3"}]}

Rules:
- The "recommendations" field MUST be a single array containing movie objects
- Each movie object has: "title" (string), "year" (number), "why" (string)
- Include 3-5 movies in the recommendations array
- Prefer well-known movies
- NEVER recommend any movie the user mentions in their message - recommend SIMILAR movies instead
- First extract movies mentioned by the user into "user_mentioned_movies", then recommend DIFFERENT movies
- Provide variety in your recommendations"""

FEW_SHOT_EXAMPLES = [
    {
        "user": {
            "mood": "Dark & Intense",
            "genres": ["Horror", "Thriller"],
            "pace": "Fast-paced",
            "viewing_context": "Solo",
            "era": "Recent",
            "open_ended": "Recently I watched a cool movie called Skinamarink. I like tense movies with clever twists, not gore."
        },
        "assistant": {
            "user_mentioned_movies": ["Skinamarink"],
            "recommendations": [
                {"title": "A Quiet Place", "year": 2018, "why": "Tense survival horror with clever premise and minimal gore."},
                {"title": "Get Out", "year": 2017, "why": "Psychological thriller with sharp twists and social commentary."},
                {"title": "It Follows", "year": 2014, "why": "Atmospheric horror with unique concept and building dread."},
                {"title": "Don't Breathe", "year": 2016, "why": "Intense home invasion thriller with constant suspense."}
            ]
        }
    },
    {
        "user": {
            "mood": "Emotional & Deep",
            "genres": ["Drama"],
            "pace": "Slow & character-driven",
            "viewing_context": "Solo",
            "era": "Classic",
            "open_ended": "I love character growth and bittersweet endings. Kinda like the Shawshank Redemption."
        },
        "assistant": {
            "user_mentioned_movies": ["Shawshank Redemption"],
            "recommendations": [
                {"title": "Good Will Hunting", "year": 1997, "why": "Character-driven drama with emotional growth and warmth."},
                {"title": "Forrest Gump", "year": 1994, "why": "Heartfelt journey through life with bittersweet moments."},
                {"title": "The Green Mile", "year": 1999, "why": "Emotional prison drama with powerful character arcs."},
                {"title": "Dead Poets Society", "year": 1989, "why": "Inspiring story about finding your voice and passion."}
            ]
        }
    },
    {
        "user": {
            "mood": "Light & Fun",
            "genres": ["Comedy", "Animation"],
            "pace": "Fast-paced",
            "viewing_context": "Family",
            "era": "2010s",
            "open_ended": "I loved Spider-Man: Into the Spider-Verse because it was funny, stylish, and heartfelt."
        },
        "assistant": {
            "user_mentioned_movies": ["Spider-Man: Into the Spider-Verse"],
            "recommendations": [
                {"title": "The Lego Movie", "year": 2014, "why": "Colorful animated adventure with humor and heart."},
                {"title": "Big Hero 6", "year": 2014, "why": "Stylish superhero animation with emotional depth."},
                {"title": "Coco", "year": 2017, "why": "Visually stunning with heartfelt family themes."},
                {"title": "The Mitchells vs. the Machines", "year": 2021, "why": "Fast-paced comedy with unique animation style."}
            ]
        }
    }
]

USER_PROMPT_TEMPLATE = """Given the user's answers below, recommend 3-5 movies.

User answers (JSON):
{answers_json}

If the user mentions a movie, pick similar ones. Follow the rules from the system prompt. Output only the JSON object."""


# ============================================================================
# MODEL FUNCTIONS
# ============================================================================
def build_messages(user_answers: dict) -> list[dict]:
    """Assemble system prompt, few-shot examples, and user query."""
    messages = [{"role": "system", "content": SYSTEM_PROMPT}]

    for ex in FEW_SHOT_EXAMPLES:
        messages.append({
            "role": "user",
            "content": USER_PROMPT_TEMPLATE.format(
                answers_json=json.dumps(ex["user"])
            )
        })
        messages.append({
            "role": "assistant",
            "content": json.dumps(ex["assistant"])
        })

    messages.append({
        "role": "user",
        "content": USER_PROMPT_TEMPLATE.format(
            answers_json=json.dumps(user_answers)
        )
    })

    return messages


def clean_output(raw_content: str) -> str:
    """Extract the assistant's final response, stripping any <think> blocks."""
    clean_out = re.sub(r"<think>.*?</think>\s*", "", raw_content, flags=re.DOTALL)
    return clean_out.strip()


def parse_recommendation(response_text: str) -> dict:
    """Parse the JSON response from the model, handling common malformed outputs."""
    print(f"[INFO] Attempting to parse JSON from response...")

    try:
        start = response_text.find('{')
        if start == -1:
            print(f"[WARN] No JSON object found in response")
            return None

        depth = 0
        for i, char in enumerate(response_text[start:], start):
            if char == '{':
                depth += 1
            elif char == '}':
                depth -= 1
                if depth == 0:
                    json_str = response_text[start:i+1]
                    result = json.loads(json_str)
                    print(f"[INFO] Successfully parsed JSON directly")
                    return result
    except json.JSONDecodeError as e:
        print(f"[INFO] Direct JSON parsing failed: {e}")

    try:
        start = response_text.find('{')
        end = response_text.rfind('}') + 1
        if start == -1 or end == 0:
            return None

        json_str = response_text[start:end]
        json_str = re.sub(r'\],\s*\[', ', ', json_str)
        json_str = re.sub(r'\[\[(\{)', r'[\1', json_str)
        json_str = re.sub(r'(\})\]\]', r'\1]', json_str)
        json_str = re.sub(r',\s*\]', ']', json_str)
        json_str = re.sub(r',\s*\}', '}', json_str)
        json_str = re.sub(r'\}\s*\{', '}, {', json_str)
        json_str = json_str.replace("'", '"')

        result = json.loads(json_str)
        print(f"[INFO] Successfully parsed fixed JSON")
        return result
    except json.JSONDecodeError as e:
        print(f"[WARN] Fixed JSON parsing also failed: {e}")

    try:
        title_pattern = r'["\']title["\']\s*:\s*["\']([^"\']+)["\']'
        year_pattern = r'["\']year["\']\s*:\s*(\d{4})'
        why_pattern = r'["\']why["\']\s*:\s*["\']([^"\']*)["\']'

        titles = re.findall(title_pattern, response_text)
        years = re.findall(year_pattern, response_text)
        whys = re.findall(why_pattern, response_text)

        if titles:
            recommendations = []
            for i, title in enumerate(titles):
                rec = {"title": title}
                if i < len(years):
                    rec["year"] = int(years[i])
                else:
                    rec["year"] = ""
                if i < len(whys) and whys[i]:
                    rec["why"] = whys[i]
                else:
                    rec["why"] = "Recommended based on your preferences"
                recommendations.append(rec)

            return {"recommendations": recommendations, "user_mentioned_movies": []}
    except Exception as e:
        print(f"[WARN] Regex extraction failed: {e}")

    print(f"[ERROR] All parsing attempts failed")
    return None


def filter_mentioned_movies(rec: dict, user_message: str) -> dict:
    """Filter out any movies that the user mentioned from the recommendations."""
    if not rec:
        return rec

    recommendations = rec.get("recommendations", [])
    mentioned = rec.get("user_mentioned_movies", [])
    user_message_lower = user_message.lower()
    mentioned_lower = [m.lower() for m in mentioned]

    filtered_recommendations = []
    for movie in recommendations:
        title = movie.get("title", "")
        title_lower = title.lower()

        is_mentioned = False
        for mentioned_title in mentioned_lower:
            if mentioned_title in title_lower or title_lower in mentioned_title:
                is_mentioned = True
                break

        if not is_mentioned and title_lower in user_message_lower:
            is_mentioned = True

        if not is_mentioned:
            filtered_recommendations.append(movie)

    rec["recommendations"] = filtered_recommendations
    return rec


def format_recommendation(rec: dict, user_message: str = ""):
    """Format the recommendations as a nice response with TMDB posters and ratings."""
    if not rec:
        return "I couldn't generate proper recommendations. Please try again!"

    if user_message:
        rec = filter_mentioned_movies(rec, user_message)

    recommendations = rec.get("recommendations", [])

    if not recommendations:
        return "I couldn't generate proper recommendations. Please try again!"

    has_tmdb = bool(get_tmdb_api_key())

    if has_tmdb:
        response = "<h2>Movie Recommendations</h2>\n"
        for i, movie in enumerate(recommendations, 1):
            title = movie.get("title", "Unknown")
            year = movie.get("year", "")
            why = movie.get("why", "")
            response += format_movie_card_with_tmdb(title, year, why, i)
        response += '<p style="font-size: 0.8em; color: #888;">Movie data from TMDB</p>'
        return response
    else:
        response = "Here are my movie recommendations for you:\n\n"
        for i, movie in enumerate(recommendations, 1):
            title = movie.get("title", "Unknown")
            year = movie.get("year", "")
            why = movie.get("why", "")
            response += f"**{i}. {title}** ({year})\n"
            response += f"   {why}\n\n"

    return response


# ============================================================================
# API MODEL INFERENCE
# ============================================================================
def run_api_model(messages: list[dict], max_tokens: int, temperature: float, top_p: float) -> str:
    """Run inference using the HuggingFace Inference API."""
    print(f"[INFO] Starting API model inference...")
    print(f"[INFO] Model: {API_MODEL_NAME}")

    client = InferenceClient(model=API_MODEL_NAME)

    response = ""
    for chunk in client.chat_completion(
        messages,
        max_tokens=max_tokens,
        stream=True,
        temperature=temperature,
        top_p=top_p,
    ):
        if chunk.choices and chunk.choices[0].delta.content:
            response += chunk.choices[0].delta.content
    print(f"[INFO] API response complete ({len(response)} characters)")
    return response


# ============================================================================
# CHAT RESPONSE LOGIC
# ============================================================================
RECOMMENDATION_KEYWORDS = ["recommend", "suggest", "movie", "watch", "looking for", "i like", "want to see", "what should", "recommendations"]

def build_conversational_context(genre, mood, era, viewing_pref, pace):
    return f"""You are a movie recommendation assistant. Be concise and helpful.

User's Preferences:
- Genre: {genre or 'Not specified'}
- Mood: {mood or 'Not specified'}
- Era: {era or 'Not specified'}
- Context: {viewing_pref or 'Not specified'}
- Pace: {pace or 'Not specified'}

Rules:
1. Suggest 3-5 movies with format: **Title** (Year) - one sentence why
2. Keep responses under 200 words
3. If preferences are missing, ask ONE clarifying question
4. Do not repeat yourself or ramble"""

def process_structured_response(response, message):
    cleaned = clean_output(response)
    rec = parse_recommendation(cleaned)

    if rec:
        print(f"[INFO] Parsed {len(rec.get('recommendations', []))} recommendations")
        return format_recommendation(rec, message)
    else:
        return f"Here's my recommendation based on your preferences:\n\n{cleaned}"

def process_conversational_response(response):
    patterns = [
        r'\*\*([^*]+)\*\*\s*\((\d{4})\)',
        r'\d+\.\s*\*\*([^*]+)\*\*',
        r'\d+\.\s*([^(:\n]+)\s*\((\d{4})\)',
        r'"([^"]+)"\s*\((\d{4})\)',
    ]

    movies_found = []
    for pattern in patterns:
        matches = re.findall(pattern, response)
        for match in matches:
            if isinstance(match, tuple):
                title = match[0].strip()
                year = int(match[1]) if len(match) > 1 and match[1].isdigit() else None
            else:
                title = match.strip()
                year = None
            if title and len(title) > 2 and title not in [m['title'] for m in movies_found]:
                movies_found.append({'title': title, 'year': year})

    if not movies_found:
        return response

    if not get_tmdb_api_key():
        return response

    enhanced = "<h2>Movie Recommendations</h2>\n"
    for i, movie in enumerate(movies_found[:5], 1):
        enhanced += format_movie_card_with_tmdb(movie['title'], movie.get('year'), "", i)
    enhanced += '<p style="font-size: 0.8em; color: #888;">Movie data from TMDB</p>'

    return enhanced

def prepare_request(message, genre, mood, era, viewing_pref, pace):
    user_answers = {
        "mood": mood or "Any",
        "genres": [genre] if genre else ["Any"],
        "pace": pace or "Balanced",
        "viewing_context": viewing_pref or "Any",
        "era": era or "Any Era",
        "open_ended": message
    }

    is_recommendation_request = any(kw in message.lower() for kw in RECOMMENDATION_KEYWORDS)
    all_preferences_set = all([genre, mood, era, viewing_pref])

    return user_answers, is_recommendation_request, all_preferences_set


# ============================================================================
# FASTAPI
# ============================================================================
app = FastAPI(title="Movie Recommendation Backend (API Mode)")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class ChatRequest(BaseModel):
    message: str
    history: list[dict] = []
    genre: str | None = None
    mood: str | None = None
    era: str | None = None
    viewing_pref: str | None = None
    pace: str | None = None
    system_message: str = "You are a friendly movie recommendation chatbot."
    max_tokens: int = 512
    temperature: float = 0.3
    top_p: float = 0.95


@app.get("/health")
def health():
    return {"status": "ok", "mode": "api"}


@app.post("/chat")
def chat_endpoint(req: ChatRequest):
    message = req.message
    genre = req.genre
    mood = req.mood
    era = req.era
    viewing_pref = req.viewing_pref
    pace = req.pace

    print(f"\n{'='*60}")
    print(f"[INFO] New chat request (API MODE)")
    print(f"[INFO] User message: {message[:100]}...")

    user_answers, is_recommendation_request, all_preferences_set = prepare_request(
        message, genre, mood, era, viewing_pref, pace
    )

    if is_recommendation_request and all_preferences_set:
        print(f"[INFO] STRUCTURED recommendation mode")
        messages = build_messages(user_answers)
        response = run_api_model(messages, req.max_tokens, req.temperature, req.top_p)
        result = process_structured_response(response, message)
    else:
        print(f"[INFO] CONVERSATIONAL mode")
        messages = [{"role": "system", "content": build_conversational_context(genre, mood, era, viewing_pref, pace)}]
        messages.extend(req.history)
        messages.append({"role": "user", "content": message})
        response = run_api_model(messages, req.max_tokens, req.temperature, req.top_p)
        result = process_conversational_response(response)

    print(f"[INFO] Request complete\n{'='*60}\n")
    return {"response": result}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=9010)
