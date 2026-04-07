package com.clearpage.backend.controller;

import com.clearpage.backend.model.Summary;
import com.clearpage.backend.service.AiService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.Map;

@RestController
@RequestMapping("/api/ai")
@CrossOrigin(origins = "*")
public class AiController {

    private final AiService aiService;

    public AiController(AiService aiService) {
        this.aiService = aiService;
    }

    @PostMapping("/summarize")
    public ResponseEntity<Summary> summarize(@RequestBody SummaryRequest request) {
        if (request.getText() == null || request.getText().trim().isEmpty()) {
            return ResponseEntity.badRequest().build();
        }
        Summary summary = aiService.summarizeText(request.getText());
        return ResponseEntity.ok(summary);
    }

    @PostMapping("/ask")
    public ResponseEntity<?> ask(@RequestBody AskRequest request) {
        if (request.getQuestion() == null || request.getQuestion().trim().isEmpty()) {
            return ResponseEntity.badRequest().build();
        }
        String answer = aiService.askQuestion(request.getPageText(), request.getQuestion());
        return ResponseEntity.ok(Map.of("answer", answer));
    }

    static class AskRequest {
        private String pageText;
        private String question;
        public String getPageText() { return pageText; }
        public void setPageText(String pageText) { this.pageText = pageText; }
        public String getQuestion() { return question; }
        public void setQuestion(String question) { this.question = question; }
    }
}
