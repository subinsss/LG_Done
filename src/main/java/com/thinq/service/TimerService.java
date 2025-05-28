package com.thinq.service;

import com.thinq.model.TimerData;
import org.springframework.stereotype.Service;

@Service
public class TimerService {
    
    private TimerData currentTimer = new TimerData(false, 0, "00:00");

    public TimerData getCurrentTimer() {
        return currentTimer;
    }

    public void updateTimer(TimerData timerData) {
        this.currentTimer = timerData;
        System.out.println("📊 타이머 상태 업데이트: " + timerData);
    }

    public void startTimer() {
        currentTimer.setRunning(true);
        System.out.println("▶️ 타이머 시작됨");
    }

    public void stopTimer() {
        currentTimer.setRunning(false);
        System.out.println("⏸️ 타이머 정지됨");
    }

    public void resetTimer() {
        currentTimer = new TimerData(false, 0, "00:00");
        System.out.println("🔄 타이머 리셋됨");
    }

    public String formatTime(int seconds) {
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