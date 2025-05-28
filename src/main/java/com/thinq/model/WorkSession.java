package com.thinq.model;

import com.fasterxml.jackson.annotation.JsonFormat;
import java.time.LocalDateTime;

public class WorkSession {
    private Long id;
    private Long todoId; // 완료한 할일 ID
    private String todoTitle; // 할일 제목
    
    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime startTime;
    
    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime endTime;
    
    private int durationSeconds; // 실제 작업 시간 (초)
    private String formattedDuration; // "25:30" 형식

    // 기본 생성자
    public WorkSession() {}

    // 전체 생성자
    public WorkSession(Long id, Long todoId, String todoTitle, LocalDateTime startTime, 
                      LocalDateTime endTime, int durationSeconds, String formattedDuration) {
        this.id = id;
        this.todoId = todoId;
        this.todoTitle = todoTitle;
        this.startTime = startTime;
        this.endTime = endTime;
        this.durationSeconds = durationSeconds;
        this.formattedDuration = formattedDuration;
    }

    // Getters and Setters
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Long getTodoId() {
        return todoId;
    }

    public void setTodoId(Long todoId) {
        this.todoId = todoId;
    }

    public String getTodoTitle() {
        return todoTitle;
    }

    public void setTodoTitle(String todoTitle) {
        this.todoTitle = todoTitle;
    }

    public LocalDateTime getStartTime() {
        return startTime;
    }

    public void setStartTime(LocalDateTime startTime) {
        this.startTime = startTime;
    }

    public LocalDateTime getEndTime() {
        return endTime;
    }

    public void setEndTime(LocalDateTime endTime) {
        this.endTime = endTime;
    }

    public int getDurationSeconds() {
        return durationSeconds;
    }

    public void setDurationSeconds(int durationSeconds) {
        this.durationSeconds = durationSeconds;
    }

    public String getFormattedDuration() {
        return formattedDuration;
    }

    public void setFormattedDuration(String formattedDuration) {
        this.formattedDuration = formattedDuration;
    }

    @Override
    public String toString() {
        return String.format("WorkSession{id=%d, todoTitle='%s', duration=%s, startTime=%s}", 
                           id, todoTitle, formattedDuration, startTime);
    }
} 