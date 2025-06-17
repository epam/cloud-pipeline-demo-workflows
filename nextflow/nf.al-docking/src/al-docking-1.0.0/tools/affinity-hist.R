#!/usr/bin/env Rscript

# Load required libraries
library(ggplot2)

# Set the file path
file_path <- "analysis/test/iterations/1IEP-0000/training-1IEP-0000-docking.csv"

# Check if file exists
if (!file.exists(file_path)) {
    cat("Error: File not found:", file_path, "\n")
    quit(status = 1)
}

# Read the CSV file
data <- try(read.csv(file_path))
if (inherits(data, "try-error")) {
    cat("Error: Could not read CSV file.\n")
    quit(status = 1)
}

# Check if 'affinity' column exists
if (!"affinity" %in% colnames(data)) {
    cat("Error: 'affinity' column not found in the CSV file.\n")
    quit(status = 1)
}

# Create histogram
p <- ggplot(data, aes(x=affinity)) +
    geom_histogram(binwidth = function(x) diff(range(x))/30, fill="#69b3a2", color="#000000", alpha=0.7) +
    labs(title="Histogram of Affinity Values",
             x="Affinity",
             y="Count") +
    theme_minimal()

# Save the plot to a PDF file
output_file <- "affinity_histogram.pdf"
ggsave(output_file, plot=p, width=8, height=6)

# Also save as PNG
output_png <- "affinity_histogram.png"
ggsave(output_png, plot=p, width=8, height=6)

cat("Histogram created and saved as", output_file, "and", output_png, "\n")

# Display basic statistics
cat("\nBasic statistics for 'affinity':\n")
cat("Min:", min(data$affinity), "\n")
cat("Max:", max(data$affinity), "\n")
cat("Mean:", mean(data$affinity), "\n")
cat("Median:", median(data$affinity), "\n")
cat("Standard deviation:", sd(data$affinity), "\n")