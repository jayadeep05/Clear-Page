package com.clearpage.backend.service;

import com.clearpage.backend.model.Summary;
import com.clearpage.backend.repository.SummaryRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import com.fasterxml.jackson.core.json.JsonReadFeature;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.json.JsonMapper;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

@Service
public class AiService {

    @Value("${openai.api.key}")
    private String openAiApiKey;

    private final SummaryRepository summaryRepository;
    private final RestTemplate restTemplate = new RestTemplate();
    // Standard mapper for parsing Groq's outer response envelope
    private final ObjectMapper objectMapper = new ObjectMapper();
    // Lenient mapper for parsing the AI-generated inner JSON (may contain unescaped
    // newlines)
    private final ObjectMapper lenientMapper = JsonMapper.builder()
            .enable(JsonReadFeature.ALLOW_UNESCAPED_CONTROL_CHARS)
            .build();

    public AiService(SummaryRepository summaryRepository) {
        this.summaryRepository = summaryRepository;
    }

    public Summary summarizeText(String text) {
        String hash = generateHash(text);

        Summary summaryEntity;
        Optional<Summary> existing = summaryRepository.findByContentHash(hash);
        if (existing.isPresent()) {
            summaryEntity = existing.get();
            if (summaryEntity.getCoreExplanation() != null && !summaryEntity.getCoreExplanation().trim().isEmpty()) {
                return summaryEntity;
            }
        } else {
            summaryEntity = new Summary();
            summaryEntity.setContentHash(hash);
            summaryEntity.setOriginalText(text);
        }

        String prompt = "You are a highly skilled teacher who explains complex technical concepts in very simple English.\n"
                + "Your goal is to help the user understand the given text clearly, step by step.\n\n"
                + "USER CONTEXT:\n"
                + "- The user knows basic backend development (Spring Boot, APIs, REST)\n"
                + "- The user is NEW to microservices architecture\n"
                + "- Always connect explanations to Spring Boot / backend concepts where helpful\n\n"
                + "STYLE REQUIREMENTS (VERY IMPORTANT):\n"
                + "- Teach like a real teacher, not like a summary tool\n"
                + "- Be conversational but structured\n"
                + "- Do NOT sound robotic\n"
                + "- Explain everything without skipping\n"
                + "- Break complex lines into simple meaning\n"
                + "- Bold only truly very very important terms (not every term)\n"
                + "- Avoid overusing bold — keep it readable\n\n"
                + "TEACHING FLOW (VERY IMPORTANT):\n"
                + "- Use guiding phrases naturally as you explain, like:\n"
                + "  'Now, important idea:'\n"
                + "  'Think like this:'\n"
                + "  'Example:'\n"
                + "  'Why this matters:'\n"
                + "- Make the explanation feel like a teacher talking step-by-step\n"
                + "- When possible, explain using simple mental models or analogies\n"
                + "- Help the user visualize the concept in real-world terms\n\n"
                + "HIGHLIGHT STYLE:\n"
                + "- For critical ideas, prefix them in bold like:\n"
                + "  **Very important:** ...\n"
                + "  **Key idea:** ...\n"
                + "  **Important rule:** ...\n\n"
                + "STRUCTURE YOUR ANSWER USING THIS FORMAT (follow closely but prioritize clarity):\n\n"
                + "# What This Section Is About\n"
                + "- Explain in 1-2 lines what the page is saying overall\n\n"
                + "# Step-by-Step Explanation\n"
                + "- Break the content into small logical parts\n"
                + "- Use guiding phrases: 'Think like this:', 'Example:', 'Why this matters:'\n"
                + "- Explain each part in simple English\n"
                + "- Rewrite difficult sentences into easy meaning\n"
                + "- Do NOT skip any idea\n\n"
                + "# Important Concepts (If Any)\n"
                + "- For each key concept:\n"
                + "  - Add a small ### heading\n"
                + "  - Explain like teaching a beginner\n"
                + "  - Use a simple real-world analogy or example\n"
                + "  - Use **Key idea:**, **Very important:**, **Important rule:** where needed\n\n"
                + "# What This Means in Simple Terms (Very Important)\n"
                + "- Explain the overall idea AGAIN in the simplest possible way\n"
                + "- Assume the user is hearing this concept for the first time\n"
                + "- Use an analogy or everyday comparison if possible\n\n"
                + "# What This Page Teaches\n"
                + "- 5 to 7 clear bullet points\n"
                + "- Cover all important ideas from the page\n\n"
                + "RULES:\n"
                + "- Use very simple English\n"
                + "- Use short sentences\n"
                + "- Each explanation block should be 2–4 lines max\n"
                + "- Break content into small readable chunks\n"
                + "- Do NOT introduce concepts not in the page\n"
                + "- Do NOT skip anything important\n\n"
                + "CRITICAL:\n"
                + "- If you cannot follow the structure, still return valid JSON\n"
                + "- NEVER break JSON format\n\n"
                + "OUTPUT FORMAT (MANDATORY):\n"
                + "Return ONLY a JSON object. No text before or after it. No greetings.\n"
                + "{ \"explanation\": \"Good. I will explain this in very simple English.\\n\\n<full structured explanation here>\" }\n\n"
                + "Here is the page text:\n" + text;

        try {
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.setBearerAuth(openAiApiKey);

            Map<String, Object> requestBody = new HashMap<>();
            requestBody.put("model", "llama-3.3-70b-versatile");

            Map<String, String> systemMessage = new HashMap<>();
            systemMessage.put("role", "system");
            systemMessage.put("content",
                    "You are a patient, skilled teacher who explains technical concepts step-by-step in very simple English. "
                            + "You are confident, calm, and always explain clearly without confusion. "
                            + "You always teach like you are talking to a beginner, use analogies, and never skip anything important. "
                            + "You produce valid JSON output with an 'explanation' field containing well-structured markdown. "
                            + "CRITICAL: Your entire response must be a valid JSON object starting with '{' and ending with '}'. "
                            + "Do NOT write any text before or after the JSON.");

            Map<String, String> message = new HashMap<>();
            message.put("role", "user");
            message.put("content", prompt);

            requestBody.put("messages", new Object[] { systemMessage, message });
            requestBody.put("temperature", 0.3);
            requestBody.put("max_completion_tokens", 4000);

            HttpEntity<Map<String, Object>> entity = new HttpEntity<>(requestBody, headers);

            ResponseEntity<String> response = restTemplate.postForEntity(
                    "https://api.groq.com/openai/v1/chat/completions",
                    entity,
                    String.class);

            JsonNode root = objectMapper.readTree(response.getBody());
            String responseContent = root.path("choices").get(0).path("message").path("content").asText();

            // Strip markdown code fences if the model wraps the JSON
            if (responseContent.contains("```json")) {
                int start = responseContent.indexOf("```json") + 7;
                int end = responseContent.lastIndexOf("```");
                if (end > start)
                    responseContent = responseContent.substring(start, end).trim();
            } else if (responseContent.startsWith("```")) {
                int end = responseContent.lastIndexOf("```");
                responseContent = responseContent.substring(3, end > 3 ? end : responseContent.length()).trim();
            }

            // Extract only the JSON object — strips any preamble text the model outputs
            // before '{'
            responseContent = extractJson(responseContent);

            // Use lenient parser — AI often returns literal newlines inside JSON string
            // values
            JsonNode jsonResponse;
            try {
                jsonResponse = lenientMapper.readTree(responseContent);
            } catch (Exception parseEx) {
                // Last resort: sanitize by escaping bare control chars, then retry
                responseContent = sanitizeJsonString(responseContent);
                jsonResponse = lenientMapper.readTree(responseContent);
            }

            // Read the single 'explanation' field — everything in one structured markdown
            // block
            String explanation = jsonResponse.path("explanation").asText();
            // Fallback: some models may still use 'coreExplanation'
            if (explanation.isBlank()) {
                explanation = jsonResponse.path("coreExplanation").asText();
            }
            summaryEntity.setCoreExplanation(explanation);
            summaryEntity.setTerminologyBreakdown("");
            summaryEntity.setPracticalUnderstanding("");
            summaryEntity.setClarifications("");
            summaryEntity.setMentalModel("");

            return summaryRepository.save(summaryEntity);

        } catch (Exception e) {
            e.printStackTrace();
            Summary temp = new Summary();
            temp.setOriginalText(text);
            temp.setCoreExplanation("Could not process with AI at this moment. " + e.getMessage());
            temp.setContentHash(hash);
            return temp;
        }
    }

    public String askQuestion(String pageText, String question) {
        String prompt = "You are a precise AI tutor helping a user understand a page from a technical book.\n"
                + "The user is a backend developer learning microservices.\n\n"
                + "Here is the content of the current page:\n"
                + "---\n" + (pageText != null ? pageText : "") + "\n---\n\n"
                + "The user asks: \"" + question + "\"\n\n"
                + "Rules:\n"
                + "- Answer ONLY based on what is present in the page content above.\n"
                + "- If the answer is not in the page, say: 'This page does not cover that. Try asking about what you see on this page.'\n"
                + "- Answer in simple English\n"
                + "- Use short structured explanation (not long paragraphs)\n"
                + "- Break into 2–4 small sections if needed\n"
                + "- Connect to Spring Boot / backend concepts where helpful.";

        try {
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.setBearerAuth(openAiApiKey);

            Map<String, Object> requestBody = new HashMap<>();
            requestBody.put("model", "llama-3.3-70b-versatile");

            Map<String, String> message = new HashMap<>();
            message.put("role", "user");
            message.put("content", prompt);

            requestBody.put("messages", new Object[] { message });
            requestBody.put("temperature", 0.5);
            requestBody.put("max_completion_tokens", 800);

            HttpEntity<Map<String, Object>> entity = new HttpEntity<>(requestBody, headers);
            ResponseEntity<String> response = restTemplate.postForEntity(
                    "https://api.groq.com/openai/v1/chat/completions", entity, String.class);

            JsonNode root = objectMapper.readTree(response.getBody());
            return root.path("choices").get(0).path("message").path("content").asText();

        } catch (Exception e) {
            e.printStackTrace();
            return "Sorry, I could not process your question at this moment. Please try again.";
        }
    }

    /**
     * Extracts a JSON object from the raw response string.
     * Strips any preamble text the AI outputs before the first '{'.
     */
    private String extractJson(String raw) {
        if (raw == null || raw.isBlank())
            return raw;
        int start = raw.indexOf('{');
        int end = raw.lastIndexOf('}');
        if (start >= 0 && end > start) {
            return raw.substring(start, end + 1).trim();
        }
        return raw;
    }

    private String generateHash(String input) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(input.getBytes(StandardCharsets.UTF_8));
            StringBuilder hexString = new StringBuilder();
            for (byte b : hash) {
                String hex = Integer.toHexString(0xff & b);
                if (hex.length() == 1)
                    hexString.append('0');
                hexString.append(hex);
            }
            return hexString.toString();
        } catch (NoSuchAlgorithmException e) {
            return String.valueOf(input.hashCode());
        }
    }

    /**
     * Escapes bare control characters inside JSON string values.
     * Handles cases where the AI writes literal newlines/tabs inside JSON strings.
     */
    private String sanitizeJsonString(String raw) {
        StringBuilder sb = new StringBuilder(raw.length());
        boolean inString = false;
        boolean escaped = false;
        for (int i = 0; i < raw.length(); i++) {
            char c = raw.charAt(i);
            if (escaped) {
                sb.append(c);
                escaped = false;
                continue;
            }
            if (c == '\\') {
                escaped = true;
                sb.append(c);
                continue;
            }
            if (c == '"') {
                inString = !inString;
                sb.append(c);
                continue;
            }
            if (inString) {
                if (c == '\n') {
                    sb.append("\\n");
                    continue;
                }
                if (c == '\r') {
                    sb.append("\\r");
                    continue;
                }
                if (c == '\t') {
                    sb.append("\\t");
                    continue;
                }
            }
            sb.append(c);
        }
        return sb.toString();
    }
}
