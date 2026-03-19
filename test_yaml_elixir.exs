Application.put_env(:yaml_elixir, :compiler, [dict: YamlElixir.Compiler])

yaml_content = File.read!("WORKFLOW_FEISHU_ASCII.md")

# Split by ---
parts = String.split(yaml_content, "---", parts: 3)

case length(parts) do
  n when n >= 2 ->
    yaml_front_matter = Enum.at(parts, 1)
    
    case YamlElixir.read_from_string(yaml_front_matter) do
      {:ok, data} ->
        IO.puts("YAML parsed successfully!")
        IO.inspect(data, pretty: true)
        
        # Check lifecycle
        lifecycle = get_in(data, ["lifecycle"])
        if lifecycle do
          IO.puts("\nlifecycle.enabled = #{lifecycle["enabled"]}")
        else
          IO.puts("\nNo lifecycle key found")
        end
        
      {:error, err} ->
        IO.puts("YAML parsing error: #{inspect(err)}")
    end
    
  _ ->
    IO.puts("No YAML front matter found")
end
