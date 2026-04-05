package com.clearpage.backend.model;

import jakarta.persistence.*;
import lombok.Data;
import java.time.LocalDateTime;

@Entity
@Data
public class Summary {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // A hash of the content to quickly find if it's already summarized
    @Column(columnDefinition = "TEXT")
    private String contentHash;

    @Column(columnDefinition = "TEXT")
    private String originalText;

    @Column(columnDefinition = "TEXT")
    private String simplifiedExplanation;

    @Column(columnDefinition = "TEXT")
    private String bulletPoints;

    @Column(columnDefinition = "TEXT")
    private String realLifeExample;

    @Column(columnDefinition = "TEXT")
    private String oneLineSummary;

    private LocalDateTime createdAt = LocalDateTime.now();
}
