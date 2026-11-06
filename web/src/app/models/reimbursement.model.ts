export type ReimbursementStatus = 'Pending' | 'Approved' | 'Rejected';

export interface Reimbursement {
  id: number;
  employeeName: string;
  amount: number;
  category: string;
  description: string;
  status: ReimbursementStatus;
  rejectionReason: string | null;
  createdAtUtc: string;
  decidedAtUtc: string | null;
}
