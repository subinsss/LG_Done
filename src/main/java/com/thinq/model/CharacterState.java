package com.thinq.model;

import com.fasterxml.jackson.annotation.JsonFormat;
import java.time.LocalDateTime;

public class CharacterState {
    private String mood; // happy, working, tired
    private String status; // 상태 메시지
    
    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime timestamp;

    // 기본 생성자
    public CharacterState() {
        this.timestamp = LocalDateTime.now();
    }

    // 전체 생성자
    public CharacterState(String mood, String status) {
        this.mood = mood;
        this.status = status;
        this.timestamp = LocalDateTime.now();
    }

    // Getters and Setters
    public String getMood() {
        return mood;
    }

    public void setMood(String mood) {
        this.mood = mood;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public LocalDateTime getTimestamp() {
        return timestamp;
    }

    public void setTimestamp(LocalDateTime timestamp) {
        this.timestamp = timestamp;
    }

    @Override
    public String toString() {
        return String.format("CharacterState{mood='%s', status='%s', timestamp=%s}", 
                           mood, status, timestamp);
    }
} 