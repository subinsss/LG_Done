package com.thinq.service;

import com.thinq.model.TodoItem;
import com.thinq.model.WorkSession;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.*;
import java.util.concurrent.atomic.AtomicLong;

@Service
public class TodoService {
    
    private final Map<Long, TodoItem> todos = new HashMap<>();
    private final List<WorkSession> workSessions = new ArrayList<>();
    private final AtomicLong todoIdCounter = new AtomicLong(1);
    private final AtomicLong sessionIdCounter = new AtomicLong(1);

    public TodoService() {
        // 초기 샘플 데이터
        addTodo(new TodoItem(null, "프로젝트 회의 참석", "오후 2시 팀 회의", false, 60));
        addTodo(new TodoItem(null, "운동하기", "30분 홈트레이닝", false, 30));
        addTodo(new TodoItem(null, "공부하기", "Flutter 문서 읽기", false, 45));
    }

    // 모든 할일 조회
    public List<TodoItem> getAllTodos() {
        return new ArrayList<>(todos.values());
    }

    // 미완료 할일만 조회 (ESP32 디스플레이용)
    public List<TodoItem> getIncompleteTodos() {
        return todos.values().stream()
                .filter(todo -> !todo.isCompleted())
                .sorted(Comparator.comparing(TodoItem::getCreatedAt))
                .toList();
    }

    // 할일 추가
    public TodoItem addTodo(TodoItem todoItem) {
        Long id = todoIdCounter.getAndIncrement();
        todoItem.setId(id);
        todos.put(id, todoItem);
        System.out.println("📝 새 할일 추가: " + todoItem);
        return todoItem;
    }

    // 할일 완료 처리
    public TodoItem completeTodo(Long todoId, LocalDateTime startTime, LocalDateTime endTime, int durationSeconds) {
        TodoItem todo = todos.get(todoId);
        if (todo != null && !todo.isCompleted()) {
            todo.setCompleted(true);
            
            // 작업 세션 기록
            WorkSession session = new WorkSession(
                sessionIdCounter.getAndIncrement(),
                todoId,
                todo.getTitle(),
                startTime,
                endTime,
                durationSeconds,
                formatDuration(durationSeconds)
            );
            workSessions.add(session);
            
            System.out.println("✅ 할일 완료: " + todo.getTitle() + " (소요시간: " + formatDuration(durationSeconds) + ")");
            return todo;
        }
        return null;
    }

    // 할일 삭제
    public boolean deleteTodo(Long todoId) {
        TodoItem removed = todos.remove(todoId);
        if (removed != null) {
            System.out.println("🗑️ 할일 삭제: " + removed.getTitle());
            return true;
        }
        return false;
    }

    // 할일 수정
    public TodoItem updateTodo(Long todoId, TodoItem updatedTodo) {
        TodoItem existing = todos.get(todoId);
        if (existing != null) {
            existing.setTitle(updatedTodo.getTitle());
            existing.setDescription(updatedTodo.getDescription());
            existing.setEstimatedMinutes(updatedTodo.getEstimatedMinutes());
            System.out.println("📝 할일 수정: " + existing);
            return existing;
        }
        return null;
    }

    // 특정 할일 조회
    public TodoItem getTodoById(Long todoId) {
        return todos.get(todoId);
    }

    // 작업 세션 기록 조회
    public List<WorkSession> getWorkSessions() {
        return new ArrayList<>(workSessions);
    }

    // 오늘의 작업 세션만 조회
    public List<WorkSession> getTodayWorkSessions() {
        LocalDateTime startOfDay = LocalDateTime.now().toLocalDate().atStartOfDay();
        return workSessions.stream()
                .filter(session -> session.getStartTime().isAfter(startOfDay))
                .sorted(Comparator.comparing(WorkSession::getStartTime).reversed())
                .toList();
    }

    // 진행률 계산
    public Map<String, Object> getProgress() {
        List<TodoItem> allTodos = getAllTodos();
        long completedCount = allTodos.stream().filter(TodoItem::isCompleted).count();
        
        Map<String, Object> progress = new HashMap<>();
        progress.put("totalTodos", allTodos.size());
        progress.put("completedTodos", completedCount);
        progress.put("progressPercentage", allTodos.isEmpty() ? 0 : (double) completedCount / allTodos.size() * 100);
        progress.put("timestamp", LocalDateTime.now());
        
        return progress;
    }

    // 시간 포맷팅 (초 → "MM:SS" 또는 "HH:MM:SS")
    private String formatDuration(int seconds) {
        int hours = seconds / 3600;
        int minutes = (seconds % 3600) / 60;
        int secs = seconds % 60;
        
        if (hours > 0) {
            return String.format("%02d:%02d:%02d", hours, minutes, secs);
        } else {
            return String.format("%02d:%02d", minutes, secs);
        }
    }
} 