export const states = [
  "All",
  "Tamil Nadu",
  "Kerala",
  "Karnataka",
  "Andhra Pradesh",
  "Telangana",
  "Maharashtra",
  "Delhi",
  "Uttar Pradesh",
  "West Bengal",
  "Gujarat",
  "Rajasthan"
];

export const districts: Record<string, string[]> = {
  "Tamil Nadu": ["All", "Chennai", "Madurai", "Coimbatore", "Trichy", "Salem", "Tirunelveli", "Erode", "Vellore", "Thanjavur"],
  "Kerala": ["All", "Thiruvananthapuram", "Kochi", "Kozhikode", "Thrissur", "Kollam", "Palakkad", "Alappuzha", "Kottayam"],
  "Karnataka": ["All", "Bengaluru", "Mysuru", "Hubballi-Dharwad", "Mangaluru", "Belagavi", "Kalaburagi", "Davanagere"],
  "Andhra Pradesh": ["All", "Visakhapatnam", "Vijayawada", "Guntur", "Nellore", "Kurnool", "Rajahmundry", "Tirupati"],
  "Telangana": ["All", "Hyderabad", "Warangal", "Nizamabad", "Karimnagar", "Ramagundam", "Khammam", "Mahbubnagar"],
};

export const getDistrictsForState = (state: string) => {
  return districts[state] || ["All"];
};
