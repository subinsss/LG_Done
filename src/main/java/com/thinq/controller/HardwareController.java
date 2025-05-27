package com.thinq.controller;

import com.thinq.model.TimerData;
import com.thinq.model.CharacterState;
import com.thinq.model.TodoProgress;
import com.thinq.model.TodoItem;
import com.thinq.model.WorkSession;
import com.thinq.service.TimerService;
import com.thinq.service.TodoService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

@RestController
@CrossOrigin(origins = "*")
@RequestMapping("/api")
public class HardwareController {

    @Autowired
    private TimerService timerService;
    
    @Autowired
    private TodoService todoService;

    // ===== ESP32에서 호출하는 API =====
    
    @PostMapping("/esp32/timer/update")
    public ResponseEntity<String> updateTimerFromESP32(@RequestBody TimerData timerData) {
        System.out.println("⏰ ESP32에서 타이머 데이터 수신: " + timerData);
        timerService.updateTimer(timerData);
        return ResponseEntity.ok("타이머 데이터 업데이트 완료");
    }

    @PostMapping("/esp32/timer/start")
    public ResponseEntity<String> startTimerFromESP32() {
        System.out.println("▶️ ESP32에서 타이머 시작 요청");
        timerService.startTimer();
        return ResponseEntity.ok("타이머 시작됨");
    }

    @PostMapping("/esp32/timer/stop")
    public ResponseEntity<String> stopTimerFromESP32() {
        System.out.println("⏸️ ESP32에서 타이머 정지 요청");
        timerService.stopTimer();
        return ResponseEntity.ok("타이머 정지됨");
    }

    @PostMapping("/esp32/timer/reset")
    public ResponseEntity<String> resetTimerFromESP32() {
        System.out.println("🔄 ESP32에서 타이머 리셋 요청");
        timerService.resetTimer();
        return ResponseEntity.ok("타이머 리셋됨");
    }

    // ESP32에서 할일 목록 요청 (디스플레이용)
    @GetMapping("/esp32/todos")
    public ResponseEntity<List<TodoItem>> getTodosForESP32() {
        List<TodoItem> incompleteTodos = todoService.getIncompleteTodos();
        System.out.println("📋 ESP32에서 할일 목록 요청: " + incompleteTodos.size() + "개");
        return ResponseEntity.ok(incompleteTodos);
    }

    // ESP32에서 할일 완료 처리
    @PostMapping("/esp32/todo/complete")
    public ResponseEntity<Map<String, Object>> completeTodoFromESP32(@RequestBody Map<String, Object> request) {
        try {
            Long todoId = Long.valueOf(request.get("todoId").toString());
            String startTimeStr = request.get("startTime").toString();
            String endTimeStr = request.get("endTime").toString();
            int durationSeconds = Integer.parseInt(request.get("durationSeconds").toString());
            
            LocalDateTime startTime = LocalDateTime.parse(startTimeStr);
            LocalDateTime endTime = LocalDateTime.parse(endTimeStr);
            
            TodoItem completedTodo = todoService.completeTodo(todoId, startTime, endTime, durationSeconds);
            
            if (completedTodo != null) {
                System.out.println("✅ ESP32에서 할일 완료: " + completedTodo.getTitle());
                return ResponseEntity.ok(Map.of(
                    "success", true,
                    "message", "할일이 완료되었습니다",
                    "completedTodo", completedTodo
                ));
            } else {
                return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "message", "할일을 찾을 수 없거나 이미 완료되었습니다"
                ));
            }
        } catch (Exception e) {
            System.err.println("❌ ESP32 할일 완료 처리 오류: " + e.getMessage());
            return ResponseEntity.badRequest().body(Map.of(
                "success", false,
                "message", "할일 완료 처리 중 오류가 발생했습니다"
            ));
        }
    }

    // ===== Flutter 앱에서 호출하는 API =====

    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> healthCheck() {
        return ResponseEntity.ok(Map.of(
            "status", "ok",
            "timestamp", java.time.LocalDateTime.now().toString()
        ));
    }

    @GetMapping("/timer")
    public ResponseEntity<TimerData> getTimer() {
        TimerData timer = timerService.getCurrentTimer();
        return ResponseEntity.ok(timer);
    }

    @PostMapping("/timer/start")
    public ResponseEntity<Map<String, String>> startTimer() {
        System.out.println("▶️ Flutter에서 타이머 시작 요청");
        timerService.startTimer();
        return ResponseEntity.ok(Map.of("success", "true", "message", "타이머가 시작되었습니다"));
    }

    @PostMapping("/timer/stop")
    public ResponseEntity<Map<String, String>> stopTimer() {
        System.out.println("⏸️ Flutter에서 타이머 정지 요청");
        timerService.stopTimer();
        return ResponseEntity.ok(Map.of("success", "true", "message", "타이머가 정지되었습니다"));
    }

    @PostMapping("/timer/reset")
    public ResponseEntity<Map<String, String>> resetTimer() {
        System.out.println("🔄 Flutter에서 타이머 리셋 요청");
        timerService.resetTimer();
        return ResponseEntity.ok(Map.of("success", "true", "message", "타이머가 리셋되었습니다"));
    }

    @PostMapping("/character")
    public ResponseEntity<Map<String, String>> receiveCharacterState(@RequestBody CharacterState characterState) {
        System.out.println("🎭 Flutter에서 캐릭터 상태 수신: " + characterState);
        return ResponseEntity.ok(Map.of("success", "true", "message", "캐릭터 상태를 받았습니다"));
    }

    @PostMapping("/todo-progress")
    public ResponseEntity<Map<String, String>> receiveTodoProgress(@RequestBody TodoProgress todoProgress) {
        System.out.println("📝 Flutter에서 할일 진행률 수신: " + todoProgress);
        return ResponseEntity.ok(Map.of("success", "true", "message", "할일 진행률을 받았습니다"));
    }

    // ===== 할일 관리 API (Flutter용) =====

    @GetMapping("/todos")
    public ResponseEntity<List<TodoItem>> getAllTodos() {
        return ResponseEntity.ok(todoService.getAllTodos());
    }

    @PostMapping("/todos")
    public ResponseEntity<TodoItem> addTodo(@RequestBody TodoItem todoItem) {
        TodoItem created = todoService.addTodo(todoItem);
        return ResponseEntity.ok(created);
    }

    @PutMapping("/todos/{id}")
    public ResponseEntity<TodoItem> updateTodo(@PathVariable Long id, @RequestBody TodoItem todoItem) {
        TodoItem updated = todoService.updateTodo(id, todoItem);
        if (updated != null) {
            return ResponseEntity.ok(updated);
        }
        return ResponseEntity.notFound().build();
    }

    @DeleteMapping("/todos/{id}")
    public ResponseEntity<Map<String, String>> deleteTodo(@PathVariable Long id) {
        boolean deleted = todoService.deleteTodo(id);
        if (deleted) {
            return ResponseEntity.ok(Map.of("success", "true", "message", "할일이 삭제되었습니다"));
        }
        return ResponseEntity.notFound().build();
    }

    @GetMapping("/todos/progress")
    public ResponseEntity<Map<String, Object>> getTodoProgress() {
        return ResponseEntity.ok(todoService.getProgress());
    }

    @GetMapping("/work-sessions")
    public ResponseEntity<List<WorkSession>> getWorkSessions() {
        return ResponseEntity.ok(todoService.getWorkSessions());
    }

    @GetMapping("/work-sessions/today")
    public ResponseEntity<List<WorkSession>> getTodayWorkSessions() {
        return ResponseEntity.ok(todoService.getTodayWorkSessions());
    }
} 