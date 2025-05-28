package com.thinq.model;

import com.fasterxml.jackson.annotation.JsonFormat;
import java.time.LocalDateTime;

public class TodoProgress {
    private int totalTodos;
    private int completedTodos;
    private double progressPercentage;
    
    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime timestamp;

    // 기본 생성자
    public TodoProgress() {
        this.timestamp = LocalDateTime.now();
    }

    // 전체 생성자
    public TodoProgress(int totalTodos, int completedTodos, double progressPercentage) {
        this.totalTodos = totalTodos;
        this.completedTodos = completedTodos;
        this.progressPercentage = progressPercentage;
        this.timestamp = LocalDateTime.now();
    }

    // Getters and Setters
    public int getTotalTodos() {
        return totalTodos;
    }

    public void setTotalTodos(int totalTodos) {
        this.totalTodos = totalTodos;
    }

    public int getCompletedTodos() {
        return completedTodos;
    }

    public void setCompletedTodos(int completedTodos) {
        this.completedTodos = completedTodos;
    }

    public double getProgressPercentage() {
        return progressPercentage;
    }

    public void setProgressPercentage(double progressPercentage) {
        this.progressPercentage = progressPercentage;
    }

    public LocalDateTime getTimestamp() {
        return timestamp;
    }

    public void setTimestamp(LocalDateTime timestamp) {
        this.timestamp = timestamp;
    }

    @Override
    public String toString() {
        return String.format("TodoProgress{totalTodos=%d, completedTodos=%d, progressPercentage=%.1f%%, timestamp=%s}", 
                           totalTodos, completedTodos, progressPercentage, timestamp);
    }
} 