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
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

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
    private final ObjectMapper objectMapper = new ObjectMapper();

    public AiService(SummaryRepository summaryRepository) {
        this.summaryRepository = summaryRepository;
    }

    public Summary summarizeText(String text) {
        String hash = generateHash(text);
        
        Optional<Summary> existing = summaryRepository.findByContentHash(hash);
        if (existing.isPresent()) {
            return existing.get();
        }

        // It's a new text, call OpenAI
        String prompt = "You are an AI reading assistant. The user is reading a book and needs help understanding the following text. "
                + "Please provide a response in clear, simple English without jargon. "
                + "Return the response in the following JSON format strictly:\n"
                + "{\n"
                + "  \"simplifiedExplanation\": \"A very simple explanation...\",\n"
                + "  \"bulletPoints\": \"- point 1\\n- point 2\",\n"
                + "  \"realLifeExample\": \"A real life example...\",\n"
                + "  \"oneLineSummary\": \"One line summary...\"\n"
                + "}\n\n"
                + "Text to summarize: " + text;

        try {
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.setBearerAuth(openAiApiKey);

            Map<String, Object> requestBody = new HashMap<>();
            requestBody.put("model", "gpt-3.5-turbo");
            
            Map<String, String> message = new HashMap<>();
            message.put("role", "user");
            message.put("content", prompt);
            
            requestBody.put("messages", new Object[]{message});
            requestBody.put("temperature", 0.7);

            HttpEntity<Map<String, Object>> entity = new HttpEntity<>(requestBody, headers);

            ResponseEntity<String> response = restTemplate.postForEntity(
                    "https://api.openai.com/v1/chat/completions",
                    entity,
                    String.class
            );

            JsonNode root = objectMapper.readTree(response.getBody());
            String responseContent = root.path("choices").get(0).path("message").path("content").asText();

            // Find JSON inside the response (sometimes models add markdown formatting like ```json ...)
            if (responseContent.startsWith("```json")) {
                responseContent = responseContent.substring(7, responseContent.length() - 3).trim();
            } else if (responseContent.startsWith("```")) {
                responseContent = responseContent.substring(3, responseContent.length() - 3).trim();
            }

            JsonNode jsonResponse = objectMapper.readTree(responseContent);

            Summary summary = new Summary();
            summary.setContentHash(hash);
            summary.setOriginalText(text);
            summary.setSimplifiedExplanation(jsonResponse.path("simplifiedExplanation").asText());
            summary.setBulletPoints(jsonResponse.path("bulletPoints").asText());
            summary.setRealLifeExample(jsonResponse.path("realLifeExample").asText());
            summary.setOneLineSummary(jsonResponse.path("oneLineSummary").asText());

            return summaryRepository.save(summary);

        } catch (Exception e) {
            e.printStackTrace();
            // Fallback object to not crash
            Summary temp = new Summary();
            temp.setOriginalText(text);
            temp.setSimplifiedExplanation("Could not process with AI at this moment. " + e.getMessage());
            temp.setContentHash(hash);
            return temp;
        }
    }

    private String generateHash(String input) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(input.getBytes(StandardCharsets.UTF_8));
            StringBuilder hexString = new StringBuilder();
            for (byte b : hash) {
                String hex = Integer.toHexString(0xff & b);
                if (hex.length() == 1) hexString.append('0');
                hexString.append(hex);
            }
            return hexString.toString();
        } catch (NoSuchAlgorithmException e) {
            // fallback
            return String.valueOf(input.hashCode());
        }
    }
}
