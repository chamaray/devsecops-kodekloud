package com.devsecops;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;

@SpringBootTest
@AutoConfigureMockMvc
class NumericApplicationTests {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void smallerThanOrEqualToFiftyMessage() throws Exception {
        mockMvc.perform(get("/compare/49"))
                .andExpect(status().isOk())
                .andExpect(content().string("Smaller than or equal to 50"));
    }

    @Test
    void greaterThanFiftyMessage() throws Exception {
        mockMvc.perform(get("/compare/51"))
                .andExpect(status().isOk())
                .andExpect(content().string("Greater than 50"));
    }

    @Test
    void welcomeMessage() throws Exception {
        mockMvc.perform(get("/"))
                .andExpect(status().isOk());
    }
}
