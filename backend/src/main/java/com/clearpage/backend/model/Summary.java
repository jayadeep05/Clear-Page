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
    private String coreExplanation;

    @Column(columnDefinition = "TEXT")
    private String terminologyBreakdown;

    @Column(columnDefinition = "TEXT")
    private String practicalUnderstanding;

    @Column(columnDefinition = "TEXT")
    private String clarifications;

    @Column(columnDefinition = "TEXT")
    private String mentalModel;

    private LocalDateTime createdAt = LocalDateTime.now();
}
