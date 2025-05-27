package com.thinq;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.CrossOrigin;

@SpringBootApplication
@CrossOrigin(origins = "*") // Flutter 웹앱에서 접근 허용
public class ThinQHardwareServerApplication {

    public static void main(String[] args) {
        System.out.println("🚀 ThinQ Hardware Server Starting...");
        System.out.println("📱 ESP32 & Flutter 연동 서버");
        System.out.println("🌐 Server will run on: http://localhost:8080");
        System.out.println("=" * 50);
        
        SpringApplication.run(ThinQHardwareServerApplication.class, args);
    }
} 