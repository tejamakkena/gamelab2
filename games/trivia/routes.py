from flask import Blueprint, request, jsonify, render_template, session
import google.generativeai as genai
import json
import os

trivia_bp = Blueprint('trivia', __name__)

# Configure Gemini AI
genai.configure(api_key=os.environ.get('GEMINI_API_KEY'))


def generate_questions_sync(topic, difficulty, count):
    """Synchronous function to generate questions (for Socket.IO)"""
    prompt = f"""Generate {count} multiple-choice trivia questions about {topic} with {difficulty} difficulty level.

For each question, provide:
1. The question text
2. Four answer options (labeled A, B, C, D)
3. The correct answer index (0-3)
4. A brief explanation (optional)

Return the response as a JSON array with this exact structure:
[
  {"question": "Question text here?",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correct_answer": 0,
    "explanation": "Brief explanation"
  }
]

Make sure the questions are:
- Factually accurate
- Clear and unambiguous
- Appropriately difficult for {difficulty} level
- Diverse and interesting
- Have only one correct answer

Return ONLY the JSON array, no additional text."""

    model = genai.GenerativeModel('gemini-2.0-flash-exp')
    response = model.generate_content(prompt)

    response_text = response.text.strip()

    if response_text.startswith('```'):
        response_text = response_text.split('```')[1]
        if response_text.startswith('json'):
            response_text = response_text[4:]
        response_text = response_text.strip()

    questions = json.loads(response_text)
    return questions


@trivia_bp.route('/')
def index():
    return render_template('games/trivia.html')


@trivia_bp.route('/generate', methods=['POST'])
def generate_questions():
    data = request.json
    topic = data.get('topic')
    difficulty = data.get('difficulty', 'medium')
    count = data.get('count', 5)

    try:
        questions = generate_questions_sync(topic, difficulty, count)

        return jsonify({
            'success': True,
            'questions': questions
        })

    except Exception as e:
        print(f"Error generating questions: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500
