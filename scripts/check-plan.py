#!/usr/bin/env python3
"""Read a saved terraform plan as JSON and refuse the changes that hurt here.

Usage, from a root module directory:

    ../../scripts/tf-cached-secrets.sh plan -out=/tmp/p.tfplan ...
    terraform show -json /tmp/p.tfplan > /tmp/p.json
    ../../scripts/check-plan.py /tmp/p.json        # exit 1 if anything is risky

Why this exists rather than reading the plan. `var.vm_defaults` is marked
sensitive, so a human-readable plan renders the interesting parts as
"(sensitive value)":

    ~ disk {
        ~ size    = (sensitive value)
        ~ storage = (sensitive value)
      }

On 2026-10-03 that hid a plan to shrink command-center1's root disk from 250G to
54784M and to DELETE the 20G node-local etcd disk from all three Kubernetes
control-plane members. Terraform classed every bit of it as an in-place
"update", so "Plan: 0 to add, 0 to destroy" was literally true and told nobody
anything. A second pass on 2026-10-07 found the same shape again: six VMs about
to be switched from static addressing to ip=dhcp, because the module defaults
ipconfig0 to DHCP and three modules did not declare it.

Both were declaration drift, not import damage, and both were invisible in the
output a person actually reads. So: parse the JSON, and fail on

  - any delete or replace
  - any change to the disk set (size, storage, or a disk disappearing)
  - any change to an attribute in RISK, which is the list of things that change
    a running VM's identity, addressing or capacity

A plan that only adds provider defaults (agent_timeout, clone_wait and friends)
passes, because those are terraform catching up to its own schema.

Exit status is the point: 0 means the plan is boring, 1 means read it properly.
"""

import json, sys
RISK = ("ipconfig0", "nameserver", "searchdomain", "memory", "cores", "sockets",
        "name", "vmid", "target_node", "onboot", "agent")
def disks(o):
    out = []
    for blk in (o.get("disks") or []):
        for ctrl in ("scsi", "virtio", "sata", "ide"):
            for e in (blk.get(ctrl) or []):
                for slot, v in e.items():
                    for item in (v or []):
                        for x in (item.get("disk") or []):
                            out.append((slot, x.get("size"), x.get("storage")))
    return sorted(out)
d = json.load(open(sys.argv[1])); bad = 0
for rc in d.get("resource_changes", []):
    ch = rc["change"]; acts = ch["actions"]
    b, a = ch.get("before") or {}, ch.get("after") or {}
    name = rc["address"].split('"')[1] if '"' in rc["address"] else rc["address"]
    problems = []
    if "delete" in acts: problems.append("DELETE")
    if "create" in acts and b: problems.append("REPLACE")
    if disks(b) != disks(a): problems.append(f"DISKS {disks(b)} -> {disks(a)}")
    for k in RISK:
        # target_node absent in imported state is expected; flag a real change.
        if b.get(k) not in (None, "") and a.get(k) not in (None, "") and b.get(k) != a.get(k):
            problems.append(f"{k}: {b.get(k)} -> {a.get(k)}")
    bad += bool(problems)
    print(f"  {name:16} {','.join(acts):8} {'OK' if not problems else ' | '.join(problems)}")
sys.exit(1 if bad else 0)
