# --- Stage 1: Build the application ---
# Use a complete JDK image with Maven pre-installed for building
FROM maven:3.9.10-eclipse-temurin-17 AS build

# Set the working directory inside the container
WORKDIR /app

# Copy the Maven project files (pom.xml, etc.) to a separate layer to leverage Docker cache
COPY pom.xml ./
COPY .mvn .mvn

# Download dependencies (if pom.xml hasn't changed)
RUN mvn dependency:resolve

# Copy the rest of the source code
COPY src src

# Package the application into a JAR file
RUN mvn package -DskipTests

# --- Stage 2: Run the application ---
# Use a lightweight JRE (Java Runtime Environment) image for the final, production container
FROM eclipse-temurin:17-jre-alpine

# Set the working directory
WORKDIR /app

# Copy the built JAR file from the 'build' stage to the new stage
COPY --from=build /app/target/*.jar app.jar

# Define the command to run the application
ENTRYPOINT ["java", "-jar", "app.jar"]
