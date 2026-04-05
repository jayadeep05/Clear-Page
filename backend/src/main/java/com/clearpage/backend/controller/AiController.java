package com.clearpage.backend.controller;

import com.clearpage.backend.model.Summary;
import com.clearpage.backend.service.AiService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/ai")
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
}
