import { Component, inject, signal } from '@angular/core';
import { CurrencyPipe, DatePipe } from '@angular/common';
import { ReactiveFormsModule, NonNullableFormBuilder, Validators } from '@angular/forms';
import { ReimbursementService } from '../../services/reimbursement.service';
import { Reimbursement, ReimbursementStatus } from '../../models/reimbursement.model';

type FilterKey = 'Pending' | 'Approved' | 'Rejected' | 'All';

@Component({
  selector: 'app-approvals',
  imports: [CurrencyPipe, DatePipe, ReactiveFormsModule],
  templateUrl: './approvals.component.html',
  styleUrl: './approvals.component.scss',
})
export class ApprovalsComponent {
  private readonly api = inject(ReimbursementService);
  private readonly fb = inject(NonNullableFormBuilder);

  readonly items = signal<Reimbursement[]>([]);
  readonly loading = signal(false);
  readonly loadError = signal(false);
  readonly toast = signal<string | null>(null);
  readonly rejectTarget = signal<Reimbursement | null>(null);
  readonly rejecting = signal(false);
  readonly rejectServerError = signal<string | null>(null);

  readonly filter = signal<FilterKey>('Pending');

  readonly rejectForm = this.fb.group({
    reason: this.fb.control('', [Validators.required, Validators.minLength(3)]),
  });

  get reasonCtrl() {
    return this.rejectForm.controls.reason;
  }

  constructor() {
    this.load();
  }

  setFilter(key: FilterKey): void {
    this.filter.set(key);
    this.load();
  }

  load(): void {
    this.loading.set(true);
    this.loadError.set(false);
    const status: ReimbursementStatus | undefined =
      this.filter() === 'All' ? undefined : (this.filter() as ReimbursementStatus);
    this.api.getAll(status).subscribe({
      next: (data) => {
        this.items.set(data);
        this.loadError.set(false);
        this.loading.set(false);
      },
      error: () => {
        this.loadError.set(true);
        this.loading.set(false);
      },
    });
  }

  approve(item: Reimbursement): void {
    if (!confirm(`¿Aprobar la solicitud de ${item.employeeName}?`)) return;
    this.api.approve(item.id).subscribe({
      next: () => {
        this.showToast('Solicitud aprobada.');
        this.load();
      },
      error: (err) => this.handleDecisionError(err, item, 'aprobada'),
    });
  }

  openReject(item: Reimbursement): void {
    this.rejectTarget.set(item);
    this.rejectForm.controls.reason.reset();
    this.rejectServerError.set(null);
  }

  closeReject(): void {
    if (this.rejecting()) return;
    this.rejectTarget.set(null);
  }

  confirmReject(): void {
    const target = this.rejectTarget();
    if (!target || this.rejectForm.invalid) return;
    this.rejecting.set(true);
    this.rejectServerError.set(null);
    this.api.reject(target.id, this.rejectForm.controls.reason.value.trim()).subscribe({
      next: () => {
        this.rejecting.set(false);
        this.rejectTarget.set(null);
        this.showToast('Solicitud rechazada.');
        this.load();
      },
      error: (err) => {
        this.rejecting.set(false);
        this.handleRejectError(err, target);
      },
    });
  }

  private handleRejectError(err: { status?: number }, item: Reimbursement): void {
    if (err.status === 409) {
      this.rejectTarget.set(null);
      this.showToast('Esta solicitud ya fue decidida.');
      this.load();
      return;
    }
    const detail =
      err.status === 400
        ? 'La solicitud no es válida (400). Complete el motivo correctamente.'
        : 'No se pudo rechazar la solicitud. Intente de nuevo.';
    this.rejectServerError.set(detail);
    void item;
  }

  private handleDecisionError(
    err: { status?: number },
    item: Reimbursement,
    action: string,
  ): void {
    if (err.status === 409) {
      this.showToast('Esta solicitud ya fue decidida.');
      this.load();
      return;
    }
    const detail =
      err.status === 400
        ? `La solicitud no puede ser ${action} (400).`
        : `No se pudo completar la decisión. Intente de nuevo.`;
    this.showToast(detail);
    void item;
  }

  private showToast(message: string): void {
    this.toast.set(message);
    setTimeout(() => {
      if (this.toast() === message) this.toast.set(null);
    }, 3500);
  }
}
