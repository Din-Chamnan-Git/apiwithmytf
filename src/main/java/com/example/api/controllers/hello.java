package com.example.api.controllers;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class hello {

	@GetMapping("/hello")
	public String returnHello() {
		return "Hello from Spring Boot Controller!" + " Created by Din Chamnan.(Cher Pument Love Saraphy)";
	}
}

