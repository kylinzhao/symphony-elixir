# Test YAML parsing
yaml_content = File.read!("WORKFLOW_FEISHU_ASCII.md")

# Split by ---
parts = String.split(yaml_content, "---")

IO.puts("Number of --- parts: #{length(parts)}")

if length(parts) > 1 do
  yaml_part = Enum.at(parts, 1)
  IO.puts("\nYAML part (first 500 chars):")
  IO.puts(String.slice(yaml_part, 0, 500))
  
  # Check for lifecycle
  if String.contains?(yaml_part, "lifecycle:") do
    IO.puts("\n✓ Contains lifecycle:")
    
    # Find the lifecycle section
    lifecycle_lines = yaml_part
    |> String.split("\n")
    |> Enum.drop_while(&(not String.contains?(&1, "lifecycle:")))
    |> Enum.take(10)
    
    Enum.each(lifecycle_lines, &IO.puts/1)
  end
end
