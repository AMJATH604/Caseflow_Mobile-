-- Create Mohammedan Law Umbrella Act
INSERT INTO bare_acts (id, title, short_title, is_active)
VALUES (
    '11b868c7-9888-4bb7-b431-44d280310e47', 
    'Mohammedan Law (Muslim Personal Law)', 
    'Muslim Personal Law',
    true
) ON CONFLICT (id) DO NOTHING;

-- Create Hindu Law Umbrella Act
INSERT INTO bare_acts (id, title, short_title, is_active)
VALUES (
    '77c22e4c-1f63-4b8c-9c7a-5e0d4a9f6d4d', 
    'Hindu Law (Personal Law)', 
    'Hindu Law',
    true
) ON CONFLICT (id) DO NOTHING;
