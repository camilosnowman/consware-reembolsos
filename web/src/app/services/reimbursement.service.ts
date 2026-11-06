import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { Reimbursement, ReimbursementStatus } from '../models/reimbursement.model';

@Injectable({ providedIn: 'root' })
export class ReimbursementService {
  private readonly baseUrl = 'http://localhost:5000/api/reimbursements';

  constructor(private http: HttpClient) {}

  getAll(status?: ReimbursementStatus): Observable<Reimbursement[]> {
    const options = status ? { params: { status } } : undefined;
    return this.http.get<Reimbursement[]>(this.baseUrl, options);
  }

  approve(id: number): Observable<void> {
    return this.http.patch<void>(`${this.baseUrl}/${id}/approve`, {});
  }

  reject(id: number, reason: string): Observable<void> {
    return this.http.patch<void>(`${this.baseUrl}/${id}/reject`, { reason });
  }
}
