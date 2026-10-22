      if (String(field.name || '').endsWith('[action_value]')) {
        const destination = String(normalized[normalized.length - 1] || '');
        field.dataset.savedValue = destination;
        if (field.tagName === 'SELECT' && destination && !Array.from(field.options).some(option => option.value === destination)) {
          field.add(new Option('Current destination: ' + destination, destination));
        }
      }
