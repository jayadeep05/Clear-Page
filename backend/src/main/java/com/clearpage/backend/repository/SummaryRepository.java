package com.clearpage.backend.repository;

import com.clearpage.backend.model.Summary;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface SummaryRepository extends JpaRepository<Summary, Long> {
    Optional<Summary> findByContentHash(String contentHash);
}
