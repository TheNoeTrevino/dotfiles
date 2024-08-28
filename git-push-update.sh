#!/bin/bash

directories=(
  "/home/noetrevino/.config"
  "/home/noetrevino/.config/nvim"
  "/home/noetrevino/projects/apartment-project"
  "/home/noetrevino/projects/sight-reading-app"
  "/home/noetrevino/projects/perceptron-ai"
  "/home/noetrevino/projects/django-practice"
  "/home/noetrevino/data-structures-and-algos"
  "/home/noetrevino/.neorg"
)

for dir in "${directories[@]}"; do
  if [ -d "$dir/.git" ]; then
    echo "Entering directory: $dir"
    cd "$dir" || {
      echo "Failed to enter $dir"
      continue
    }

    # Perform git fetch and pull
    echo "Fetching and pulling latest changes..."
    git fetch
    git push

    echo "Done with $dir"
    echo "
    ---------------------------------
    "
  else
    echo "Directory $dir is not a git repository"
  fi
done

echo "All done!"
