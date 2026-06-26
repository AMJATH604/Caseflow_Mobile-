import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";
import { format } from "date-fns";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatDate(date: string | Date): string {
  return format(new Date(date), 'dd/MM/yyyy');
}

export function formatCurrency(amount: number): string {
  return `₹${amount.toLocaleString('en-IN')}`;
}

export function formatDateTime(date: string | Date): string {
  return format(new Date(date), 'dd/MM/yyyy, hh:mm a');
}

export function getInitials(name: string): string {
  return name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2);
}

export function getMembershipBadge(type: string): string {
  const badges: Record<string, string> = {
    regular: 'Regular',
    life: 'Life Member',
    honorary: 'Honorary',
    student: 'Student',
  };
  return badges[type] || type;
}

export function getCategoryColor(category: string): string {
  const colors: Record<string, string> = {
    general: '#6366F1',
    urgent: '#EF4444',
    election: '#7C3AED',
    event: '#0891B2',
    holiday: '#F59E0B',
    meeting: '#2563EB',
    lecture: '#10B981',
    sports: '#F59E0B',
    annual: '#7C3AED',
  };
  return colors[category] || '#64748B';
}
